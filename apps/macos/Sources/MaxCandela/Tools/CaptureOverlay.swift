import AppKit

/// Lets the user point at what to capture: a dimmed overlay on every screen,
/// on which they either drag out a box (`selectRegion`) or click a window
/// (`selectWindow`). Escape, or a click without a drag, cancels.
///
/// Shared by Screenshot and Copy Text from Screen. Each tool owns one; it
/// shows nothing until asked and holds nothing once closed.
final class CaptureOverlay {
    private var windows: [RegionSelectionWindow] = []
    private var candidates: [PickableWindow] = []
    private var onPickWindow: ((PickableWindow) -> Void)?

    var isActive: Bool { !windows.isEmpty }

    /// `completion` gets the box in AppKit global coordinates and the screen
    /// it was drawn on. Not called on cancel.
    func selectRegion(_ completion: @escaping (CGRect, NSScreen) -> Void) {
        open { screen, window in
            let view = RegionSelectionView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.onFinish = { [weak self, weak window] local in
                guard let self, let window else { return }
                self.close()
                // Inside the view's own screen only — see captureRect.
                guard let local, local.width > 4, local.height > 4 else { return }
                completion(window.convertToScreen(local), screen)
            }
            return view
        }
    }

    /// `candidates` front to back, CoreGraphics global (see
    /// `ScreenCapture.onScreenWindows()`). Not called on cancel.
    func selectWindow(from candidates: [PickableWindow], _ completion: @escaping (PickableWindow) -> Void) {
        self.candidates = candidates
        onPickWindow = completion
        open { screen, _ in
            let view = WindowSelectionView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.onMove = { [weak self] point in self?.hover(at: point) }
            view.onClick = { [weak self] point in self?.pick(at: point) }
            return view
        }
        hover(at: NSEvent.mouseLocation)
    }

    func close() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        candidates.removeAll()
        onPickWindow = nil
    }

    private func open(_ makeView: (NSScreen, RegionSelectionWindow) -> NSView) {
        close()
        NSApp.activate(ignoringOtherApps: true)
        for screen in NSScreen.screens {
            let window = RegionSelectionWindow(screen: screen) { [weak self] in self?.close() }
            window.contentView = makeView(screen, window)
            windows.append(window)
            window.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - Window mode

    private func window(at appKitPoint: CGPoint) -> PickableWindow? {
        let point = ScreenCapture.cgPoint(fromAppKit: appKitPoint, primaryHeight: ScreenCapture.primaryHeight)
        return ScreenCapture.frontmost(at: point, in: candidates)
    }

    /// Every overlay draws its share of the highlighted window — a window
    /// straddling two displays lights up on both.
    private func hover(at appKitPoint: CGPoint) {
        let frame = window(at: appKitPoint).map {
            ScreenCapture.appKitRect(fromCG: $0.frame, primaryHeight: ScreenCapture.primaryHeight)
        }
        for overlay in windows {
            (overlay.contentView as? WindowSelectionView)?.highlight = frame.map { overlay.convertFromScreen($0) }
        }
    }

    private func pick(at appKitPoint: CGPoint) {
        // A click on the bare desktop is not a choice; keep waiting.
        guard let picked = window(at: appKitPoint), let completion = onPickWindow else { return }
        close()
        completion(picked)
    }
}

/// A borderless, full-screen window above everything, hosting one of the
/// selection views below.
final class RegionSelectionWindow: NSWindow {
    private let onCancel: () -> Void

    init(screen: NSScreen, onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
        // Base designated init with global coordinates — the screen: variant
        // traps in subclasses on newer macOS (see CLAUDE.md gotchas).
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    // A borderless window refuses key status by default, and without it the
    // Escape key never arrives.
    override var canBecomeKey: Bool { true }

    /// AppKit may nudge a window off the menu bar; this one must cover the
    /// whole screen exactly, or view → screen conversions drift.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

    override func cancelOperation(_ sender: Any?) { onCancel() }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel() } else { super.keyDown(with: event) }
    }
}

/// Drag out a rectangle. Reports it in view coordinates, clipped to this
/// screen, or nil for a click without a drag.
private final class RegionSelectionView: NSView {
    var onFinish: ((CGRect?) -> Void)?
    private var start: CGPoint?
    private var selection: CGRect?

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.25).setFill()
        bounds.fill()
        guard let selection else { return }
        // Punch the selection out of the dimming so its contents read clearly.
        NSGraphicsContext.current?.compositingOperation = .clear
        selection.fill()
        NSGraphicsContext.current?.compositingOperation = .sourceOver
        NSColor.white.setStroke()
        let outline = NSBezierPath(rect: selection.insetBy(dx: 0.5, dy: 0.5))
        outline.lineWidth = 1
        outline.stroke()
        drawSize(of: selection)
    }

    /// "640 × 360" under the box, in points — what the user is choosing.
    private func drawSize(of selection: CGRect) {
        let text = "\(Int(selection.width.rounded())) × \(Int(selection.height.rounded()))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        var origin = CGPoint(x: selection.maxX - size.width - 8, y: selection.minY - size.height - 10)
        if origin.y < bounds.minY + 4 { origin.y = selection.minY + 6 }
        origin.x = max(bounds.minX + 4, origin.x)
        let badge = CGRect(origin: origin, size: size).insetBy(dx: -5, dy: -2)
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: badge, xRadius: 4, yRadius: 4).fill()
        (text as NSString).draw(at: origin, withAttributes: attributes)
    }

    override func mouseDown(with event: NSEvent) {
        start = convert(event.locationInWindow, from: nil)
        selection = nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start else { return }
        let point = convert(event.locationInWindow, from: nil)
        // The drag keeps reporting to this view after the pointer crosses
        // onto another screen; clip rather than describe a box this display
        // cannot capture.
        selection = AnnotationGeometry.rect(from: start, to: point).intersection(bounds)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let finished = selection.flatMap { $0.isNull ? nil : $0 }
        start = nil
        selection = nil
        onFinish?(finished)
    }
}

/// Hover to light up a window, click to choose it. Reports pointer positions
/// in AppKit global coordinates; the overlay decides what is under them.
private final class WindowSelectionView: NSView {
    var onMove: ((CGPoint) -> Void)?
    var onClick: ((CGPoint) -> Void)?
    /// The hovered window's frame in this view's coordinates, if it reaches
    /// this screen at all.
    var highlight: CGRect? {
        didSet { if highlight != oldValue { needsDisplay = true } }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // .activeAlways: overlays on the other screens are not key, and
        // still have to follow the pointer.
        addTrackingArea(NSTrackingArea(rect: .zero,
                                       options: [.mouseMoved, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.25).setFill()
        bounds.fill()
        guard let highlight, highlight.intersects(bounds) else { return }
        NSGraphicsContext.current?.compositingOperation = .clear
        highlight.fill()
        NSGraphicsContext.current?.compositingOperation = .sourceOver
        NSColor.controlAccentColor.withAlphaComponent(0.18).setFill()
        highlight.fill()
        NSColor.controlAccentColor.setStroke()
        let outline = NSBezierPath(rect: highlight.insetBy(dx: 1, dy: 1))
        outline.lineWidth = 2
        outline.stroke()
    }

    private func globalPoint(_ event: NSEvent) -> CGPoint? {
        window?.convertPoint(toScreen: event.locationInWindow)
    }

    override func mouseMoved(with event: NSEvent) {
        if let point = globalPoint(event) { onMove?(point) }
    }

    override func mouseDown(with event: NSEvent) {
        if let point = globalPoint(event) { onClick?(point) }
    }
}
