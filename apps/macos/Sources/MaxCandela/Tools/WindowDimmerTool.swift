import AppKit

/// Dim Background Windows (Pro): darken everything except the app you are
/// working in — HazeOver's idea, built without the Accessibility API (which
/// the App Store sandbox does not allow).
///
/// One click-through overlay per screen at `OverlayLevel.dimmer`, just above
/// every normal window. It is dark everywhere except over the frontmost app's
/// windows, which are read from the window server
/// (`CGWindowListCopyWindowInfo`: owner PID, layer and bounds of each
/// on-screen window — never names, never pixels). Menus, popovers, floating
/// palettes and alerts live above the overlay's level and are never dimmed.
///
/// Updated on every app switch and Space switch, and by a poll while it is on
/// (windows move and resize without any public notification): every 0.1 s for
/// a couple of seconds after something changed, every 0.4 s otherwise.
///
/// **Permission.** No Screen Recording prompt is asked for. CGWindow.h files
/// bounds, owner PID and layer under the always-present keys and only window
/// and owner *names* under "if present"; names have been withheld without
/// Screen Recording since macOS 10.15. But Apple documents no gating either
/// way, and DTS (forum 839069, Jul 2026) says which keys are populated
/// without the permission "is undocumented and may change at any time". So
/// the overlay fails safe: a list without bounds or owners, or without a
/// window for the front app, dims nothing — dimming nothing is always
/// preferred to dimming the window being worked in.
///
/// ⚠️ Built without running it (no GUI runs on the build Mac). The geometry
/// is unit-tested; the overlay itself has not been seen on the glass. Test
/// the permission question in the sandboxed build with Screen Recording
/// *off*: `swift run` from a terminal inherits the terminal's own grant.
/// DEBUG: `MAXCANDELA_FORCE_NO_WINDOW_BOUNDS=1` strips the bounds.
final class WindowDimmerTool: MenuTool {
    let menuItem = NSMenuItem(title: "Dim Background Windows", action: nil, keyEquivalent: "")
    var onStatusChange: (() -> Void)?
    var isPro: Bool { true }

    private static let enabledKey = "com.maxcandela.dimmer.enabled"
    private static let opacityKey = "com.maxcandela.dimmer.opacity"

    private let toggleItem = NSMenuItem(title: "Dim Windows Behind the Front App", action: nil, keyEquivalent: "")
    private let noteItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var slider: SliderMenuItemView!

    private var overlays: [CGDirectDisplayID: DimmerOverlay] = [:]
    private let displays = DisplayManager()
    private var observers: [NSObjectProtocol] = []
    private var pollTimer: Timer?
    private var tickCount = 0
    private var lastChange = Date.distantPast
    /// What is on the glass, so an unchanged poll costs no redraw.
    private var lastPlan: DimmerModel.Plan?
    private(set) var isRunning = false
    private var isShutDown = false

    private var wanted: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    private var opacity: Double {
        get {
            let saved = UserDefaults.standard.object(forKey: Self.opacityKey) as? Double
            return DimmerModel.clampedOpacity(saved ?? DimmerModel.defaultOpacity)
        }
        set { UserDefaults.standard.set(DimmerModel.clampedOpacity(newValue), forKey: Self.opacityKey) }
    }

    init() {
        let submenu = NSMenu()
        toggleItem.target = self
        toggleItem.action = #selector(toggle)
        submenu.addItem(toggleItem.symbol("square.filled.on.square"))

        slider = SliderMenuItemView(
            title: "Strength",
            symbol: "circle.lefthalf.filled",
            value: DimmerModel.slider(opacity: opacity),
            describe: { DimmerModel.percentText(opacity: DimmerModel.opacity(slider: $0)) }
        ) { [weak self] value in
            self?.setOpacity(DimmerModel.opacity(slider: value))
        }
        let sliderItem = NSMenuItem()
        sliderItem.view = slider
        submenu.addItem(sliderItem)

        noteItem.isEnabled = false
        noteItem.isHidden = true
        submenu.addItem(noteItem.symbol("exclamationmark.triangle"))
        menuItem.submenu = submenu
        menuItem.symbol("square.filled.on.square")

        displays.onScreenConfigurationChanged = { [weak self] in self?.screensChanged() }
        ProGate.shared.observe { [weak self] allowed in
            // Pro lapsed: stop dimming but keep the saved choice, the same
            // way a licence suspension keeps the boost preference.
            if allowed { self?.startIfWanted() } else { self?.stop() }
        }
        if ProGate.shared.isAllowed { startIfWanted() }
        updateMenu()
    }

    func menuWillOpen() { updateMenu() }
    func shutdown() {
        isShutDown = true
        stop()
    }

    // MARK: - Menu

    private func updateMenu() {
        toggleItem.state = isRunning ? .on : .off
        menuItem.state = isRunning ? .on : .off
        slider.isEnabled = isRunning
        if isRunning, case .dimNothing(.unreadable) = lastPlan {
            noteItem.title = "Paused — macOS is not reporting window positions"
            noteItem.isHidden = false
        } else {
            noteItem.isHidden = true
        }
    }

    @objc private func toggle() {
        if isRunning {
            wanted = false
            stop()
        } else {
            ProGate.shared.run {
                wanted = true
                startIfWanted()
            }
        }
        updateMenu()
    }

    private func setOpacity(_ value: Double) {
        opacity = value
        OverlayDrawing.withoutAnimation {
            overlays.values.forEach { $0.setOpacity(self.opacity) }
        }
    }

    // MARK: - Running

    private func startIfWanted() {
        guard wanted, !isRunning, !isShutDown, ProGate.shared.isAllowed else { return }
        isRunning = true
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification,
                     NSWorkspace.activeSpaceDidChangeNotification,
                     NSWorkspace.didWakeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.somethingChanged()
            })
        }
        // .common: keep following the windows while one of our menus is open
        // (the strength slider is dragged inside one).
        let timer = Timer(timeInterval: DimmerModel.pollInterval, repeats: true) { [weak self] _ in
            self?.pollTick()
        }
        timer.tolerance = DimmerModel.pollInterval / 5
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
        somethingChanged()
    }

    private func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers.removeAll()
        overlays.values.forEach { $0.close() }
        overlays.removeAll()
        lastPlan = nil
        isRunning = false
        updateMenu()
    }

    private func somethingChanged() {
        lastChange = Date()
        update()
    }

    private func screensChanged() {
        guard isRunning else { return }
        lastPlan = nil      // every screen's path must be recomputed
        somethingChanged()
    }

    private func pollTick() {
        tickCount &+= 1
        let every = DimmerModel.pollEvery(secondsSinceChange: Date().timeIntervalSince(lastChange))
        guard tickCount % every == 0 else { return }
        update()
    }

    private func update() {
        guard isRunning else { return }
        let list = Self.onScreenWindows()
        let screens = NSScreen.screens
        // Only regular (Dock-icon) apps other than the front one are dimmed.
        // Helpers draw *for* whatever app is in front — the Open/Save panel of
        // a sandboxed app is owned by an XPC service, not by the app — and
        // menu-bar apps are not "the background". Unknown owner: not dimmed.
        let regular = Set(NSWorkspace.shared.runningApplications.lazy
            .filter { $0.activationPolicy == .regular }
            .map(\.processIdentifier))
        let plan: DimmerModel.Plan
        if let primary = ScreenGeometry.primaryScreenHeight(screens.map(\.frame)) {
            plan = DimmerModel.plan(reading: DimmerModel.read(list),
                                    frontPID: NSWorkspace.shared.frontmostApplication?.processIdentifier,
                                    dimmablePIDs: regular,
                                    primaryScreenHeight: primary)
        } else {
            plan = .dimNothing(.unreadable)
        }
        guard plan != lastPlan else { return }
        let reasonChanged = !DimmerModel.sameReason(plan, lastPlan)
        lastPlan = plan
        lastChange = Date()
        apply(plan, on: screens)
        if reasonChanged { updateMenu() }
    }

    /// Every on-screen window, front to back (~0.6 ms with 25 windows on an
    /// M1 Pro, measured 2026-11-22).
    private static func onScreenWindows() -> [[String: Any]]? {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]]
        #if DEBUG
        // MAXCANDELA_FORCE_NO_WINDOW_BOUNDS=1: the list as a macOS that
        // withheld bounds would return it — exercises the fail-safe path.
        if ProcessInfo.processInfo.environment["MAXCANDELA_FORCE_NO_WINDOW_BOUNDS"] == "1" {
            return list?.map { $0.filter { $0.key != kCGWindowBounds as String } }
        }
        #endif
        return list
    }

    private func apply(_ plan: DimmerModel.Plan, on screens: [NSScreen]) {
        let present = Set(screens.map(ScreenGeometry.displayID(of:)))
        for (id, overlay) in overlays where !present.contains(id) {
            overlay.close()
            overlays[id] = nil
        }
        guard case .paint(let steps) = plan else {
            overlays.values.forEach { $0.hide() }
            return
        }
        OverlayDrawing.withoutAnimation {
            for screen in screens {
                let id = ScreenGeometry.displayID(of: screen)
                let path = DimmerModel.dimPath(steps: steps, screenFrame: screen.frame)
                guard !path.boundingBoxOfPath.isEmpty else {
                    // Nothing to dim here (a full-screen front window): take
                    // the overlay off this screen rather than composite an
                    // invisible full-screen layer over it.
                    overlays[id]?.hide()
                    continue
                }
                let overlay = overlays[id] ?? DimmerOverlay(screen: screen, opacity: opacity)
                overlays[id] = overlay
                overlay.show(path: path, on: screen)
            }
        }
    }
}

/// One screen's overlay: a window and the shape layer that is its dark area.
private final class DimmerOverlay {
    private let window: PassiveOverlayWindow
    private let shape = CAShapeLayer()

    init(screen: NSScreen, opacity: Double) {
        // .transient: Mission Control hides it — the holes would be wrong
        // there. .fullScreenAuxiliary: it may join a full-screen app's Space
        // (split view has a background tile to dim).
        window = PassiveOverlayWindow(
            frame: screen.frame, level: OverlayLevel.dimmer,
            behavior: [.canJoinAllSpaces, .transient, .fullScreenAuxiliary, .ignoresCycle])
        shape.fillColor = NSColor.black.cgColor
        shape.fillRule = .nonZero
        shape.opacity = Float(opacity)
        window.rootLayer.addSublayer(shape)
    }

    func show(path: CGPath, on screen: NSScreen) {
        window.place(screen.frame)
        shape.frame = window.rootLayer.bounds
        shape.contentsScale = screen.backingScaleFactor
        shape.path = path
        window.show()
    }

    func setOpacity(_ opacity: Double) {
        shape.opacity = Float(opacity)
    }

    func hide() {
        window.orderOut(nil)
    }

    func close() {
        window.orderOut(nil)
        window.close()
    }
}

/// One on-screen window as the window server reports it. `bounds` is in
/// Quartz global coordinates (see `ScreenGeometry`).
struct WindowRecord: Equatable {
    let pid: pid_t
    let layer: Int
    let bounds: CGRect
    let alpha: Double
}

/// The dimmer's decisions, pure and unit-tested (WindowDimmerTests).
enum DimmerModel {
    enum Reading: Equatable {
        /// Normal-layer (0) windows, front to back.
        case windows([WindowRecord])
        /// The list, or a normal window's owner or bounds, was missing.
        case unreadable
    }

    enum Reason: Equatable {
        case unreadable
        case noFrontApp
        case frontAppHasNoWindows
    }

    /// One rectangle painted onto the overlay, in AppKit global coordinates.
    /// `dim` false cuts a hole.
    struct Step: Equatable {
        let rect: CGRect
        let dim: Bool
    }

    enum Plan: Equatable {
        case dimNothing(Reason)
        /// Start dark everywhere, then paint these back to front.
        case paint([Step])
    }

    // MARK: Polling and strength

    static let pollInterval: TimeInterval = 0.1

    /// Poll on every tick while things are moving (a drag, a Space or app
    /// switch animating in), on every 4th once they have been still for 2 s.
    static func pollEvery(secondsSinceChange: TimeInterval) -> Int {
        secondsSinceChange < 2 ? 1 : 4
    }

    /// Overlay opacity range the slider spans: below 10% the dimming is hard
    /// to see, above 70% the background stops being readable at all.
    static let opacityRange: ClosedRange<Double> = 0.10...0.70
    /// HazeOver's default.
    static let defaultOpacity = 0.35

    static func clampedOpacity(_ value: Double) -> Double {
        min(opacityRange.upperBound, max(opacityRange.lowerBound, value))
    }

    /// Slider position (0…1) → overlay opacity.
    static func opacity(slider: Double) -> Double {
        let t = min(1, max(0, slider))
        return opacityRange.lowerBound + t * (opacityRange.upperBound - opacityRange.lowerBound)
    }

    /// Overlay opacity → slider position (0…1).
    static func slider(opacity: Double) -> Double {
        (clampedOpacity(opacity) - opacityRange.lowerBound) / (opacityRange.upperBound - opacityRange.lowerBound)
    }

    static func percentText(opacity: Double) -> String {
        "\(Int((clampedOpacity(opacity) * 100).rounded()))%"
    }

    // MARK: Reading the window list

    /// Keeps the normal-layer windows, in the list's front-to-back order.
    /// Windows on other layers (menus, the Dock, panels, our own overlays)
    /// are skipped without being looked at. A normal window with no owner or
    /// no bounds makes the whole reading unusable — a hole cannot be cut for
    /// a window whose position is unknown.
    static func read(_ list: [[String: Any]]?) -> Reading {
        guard let list else { return .unreadable }
        var windows: [WindowRecord] = []
        for entry in list {
            guard let layer = (entry[kCGWindowLayer as String] as? NSNumber)?.intValue else {
                return .unreadable
            }
            guard layer == 0 else { continue }
            guard let pid = (entry[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  let boundsDictionary = entry[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDictionary) else {
                return .unreadable
            }
            let alpha = (entry[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1
            windows.append(WindowRecord(pid: pid, layer: layer, bounds: bounds, alpha: alpha))
        }
        return .windows(windows)
    }

    // MARK: Planning

    static func plan(reading: Reading, frontPID: pid_t?, dimmablePIDs: Set<pid_t>,
                     primaryScreenHeight: CGFloat) -> Plan {
        guard let frontPID else { return .dimNothing(.noFrontApp) }
        guard case .windows(let all) = reading else { return .dimNothing(.unreadable) }
        // Invisible and degenerate windows neither cut holes nor cover any.
        let visible = all.filter { $0.layer == 0 && $0.alpha > 0 && $0.bounds.width >= 1 && $0.bounds.height >= 1 }
        // The front app with nothing to show here (only the desktop, windows
        // on another Space, or bounds macOS withheld): dimming everything
        // else would leave nothing undimmed. Dim nothing.
        guard visible.contains(where: { $0.pid == frontPID }) else {
            return .dimNothing(.frontAppHasNoWindows)
        }
        var steps = visible.reversed().map { window in
            Step(rect: ScreenGeometry.appKitRect(fromQuartz: window.bounds, primaryScreenHeight: primaryScreenHeight),
                 dim: window.pid != frontPID && dimmablePIDs.contains(window.pid))
        }
        // Dark on dark changes nothing: drop dim steps before the first hole.
        if let firstHole = steps.firstIndex(where: { !$0.dim }) {
            steps.removeFirst(firstHole)
        }
        return .paint(steps)
    }

    /// Whether `point` (AppKit global) ends up dark: the last step to cover
    /// it decides, and a point no step covers is dark. This is the reference
    /// `dimPath` is tested against.
    static func isDimmed(_ point: CGPoint, steps: [Step]) -> Bool {
        steps.last(where: { $0.rect.contains(point) })?.dim ?? true
    }

    /// The dark area of one screen, in coordinates local to that screen.
    static func dimPath(steps: [Step], screenFrame: CGRect) -> CGPath {
        let bounds = CGRect(origin: .zero, size: screenFrame.size)
        var region = CGPath(rect: bounds, transform: nil)
        for step in steps {
            let rect = ScreenGeometry.local(step.rect, in: screenFrame).intersection(bounds)
            guard !rect.isNull, !rect.isEmpty else { continue }
            let piece = CGPath(rect: rect, transform: nil)
            region = step.dim ? region.union(piece) : region.subtracting(piece)
        }
        return region
    }

    /// Whether two plans would show the same menu note.
    static func sameReason(_ a: Plan, _ b: Plan?) -> Bool {
        switch (a, b) {
        case (.dimNothing(let x), .dimNothing(let y)?): return x == y
        case (.paint, .paint?): return true
        default: return false
        }
    }
}
