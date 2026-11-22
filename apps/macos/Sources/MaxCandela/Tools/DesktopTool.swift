import AppKit
import ImageIO

/// Desktop (free): two things drawn at the desktop's own level, under every
/// app window, by one click-through window per screen.
///
/// **Hide Desktop Icons** covers Finder's icons with a copy of the wallpaper
/// (or a plain colour). The wallpaper is drawn from its *file* —
/// `NSWorkspace.desktopImageURL(for:)` laid out per `desktopImageOptions(for:)`
/// — never captured from the screen: capturing the wallpaper window needs
/// Screen Recording from macOS 27 on (forum 849969). A wallpaper file the
/// sandbox will not let us read (a photo from the user's folders, most
/// likely) is replaced by its fill colour and the menu says so; reading
/// ~/Pictures would need `com.apple.security.assets.pictures.read-only`,
/// which is deliberately not added. The icons are only hidden, not moved:
/// clicks fall through, so the desktop's right-click menu and drag-and-drop
/// still work, and a double-click on a hidden icon still opens it.
///
/// **Hide the Notch** paints the menu-bar strip of a display with a camera
/// housing black, under the menu bar, so the housing blends into it. Two
/// limits, both unverified on hardware:
///  - it only shows where the menu bar lets what is beneath it show through.
///    A third-party developer reports that from macOS 12 the menu bar's blur
///    ignored their transparent overlay windows (github.com/box-kr/no_notch,
///    v1.0.47 notes) — the frosted bar samples the wallpaper. macOS 26's
///    menu bar has no background by default (System Settings ▸ Menu Bar ▸
///    Show menu bar background), which is the case this is built for.
///  - black under dark menu-bar text would hide the menu bar, ☀️ included,
///    so the band is drawn only while the menu bar draws light text — read
///    from the appearance macOS gives our own status item
///    (`menuBarAppearance`).
/// The alternatives that work under any menu bar were rejected: a wallpaper
/// with a black band baked in is persistent system state (and a crash would
/// leave it); a display mode that ends below the housing
/// (`CGDisplaySetDisplayMode`, reverts on exit) costs the top ~33 pt of the
/// screen and reconfigures the display under the boost.
///
/// Refreshed on app switches, Space switches (each Space can have its own
/// wallpaper), wake, screen changes, Dark Mode changes and menu opens; there
/// is no public notification for a wallpaper change.
///
/// ⚠️ Built without running it (no GUI runs on the build Mac). The layout
/// maths is unit-tested; nothing here has been seen on the glass.
final class DesktopTool: MenuTool {
    let menuItem = NSMenuItem(title: "Desktop", action: nil, keyEquivalent: "")
    var onStatusChange: (() -> Void)?

    /// Supplied by MenuBarController: the appearance macOS has given our
    /// status item, i.e. what the menu bar is drawing its text with now.
    var menuBarAppearance: () -> NSAppearance? = { nil } {
        didSet { refresh() }
    }

    enum CurtainStyle: String, CaseIterable {
        case wallpaper, black, graphite, silver

        var title: String {
            switch self {
            case .wallpaper: return "Wallpaper"
            case .black: return "Black"
            case .graphite: return "Dark Grey"
            case .silver: return "Light Grey"
            }
        }

        /// Plain styles' colour; nil for the wallpaper.
        var color: NSColor? {
            switch self {
            case .wallpaper: return nil
            case .black: return .black
            case .graphite: return NSColor(white: 0.17, alpha: 1)
            case .silver: return NSColor(white: 0.78, alpha: 1)
            }
        }

        /// Pure, unit-tested: an unknown or missing saved value → wallpaper.
        static func saved(_ raw: String?) -> CurtainStyle {
            raw.flatMap(CurtainStyle.init(rawValue:)) ?? .wallpaper
        }
    }

    private static let curtainKey = "com.maxcandela.desktop.curtain"
    private static let styleKey = "com.maxcandela.desktop.curtainStyle"
    private static let notchKey = "com.maxcandela.desktop.notch"

    private let curtainItem = NSMenuItem(title: "Hide Desktop Icons", action: nil, keyEquivalent: "")
    private let styleMenu = NSMenu()
    private let wallpaperNote = NSMenuItem(title: "This wallpaper can't be read — showing a plain colour",
                                           action: nil, keyEquivalent: "")
    private let notchItem = NSMenuItem(title: "Hide the Notch", action: nil, keyEquivalent: "")
    private let notchNote = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    private var surfaces: [CGDirectDisplayID: DesktopSurface] = [:]
    /// From the last refresh, for the menu's notes.
    private var anyNotch = false
    private var notchPaused = false
    private var isShutDown = false
    private let displays = DisplayManager()
    private var observers: [NSObjectProtocol] = []
    private var appearanceObservation: NSKeyValueObservation?

    private var curtainOn: Bool {
        get { UserDefaults.standard.bool(forKey: Self.curtainKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.curtainKey) }
    }
    private var notchOn: Bool {
        get { UserDefaults.standard.bool(forKey: Self.notchKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.notchKey) }
    }
    private var style: CurtainStyle {
        get { CurtainStyle.saved(UserDefaults.standard.string(forKey: Self.styleKey)) }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Self.styleKey) }
    }

    init() {
        let submenu = NSMenu()
        curtainItem.target = self
        curtainItem.action = #selector(toggleCurtain)
        submenu.addItem(curtainItem.symbol("eye.slash"))

        let styleItem = NSMenuItem(title: "Cover With", action: nil, keyEquivalent: "")
        styleItem.submenu = styleMenu
        for option in CurtainStyle.allCases {
            let item = NSMenuItem(title: option.title, action: #selector(chooseStyle(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = option.rawValue
            styleMenu.addItem(item)
        }
        submenu.addItem(styleItem.symbol("paintpalette"))
        wallpaperNote.isEnabled = false
        submenu.addItem(wallpaperNote.symbol("exclamationmark.triangle"))

        submenu.addItem(.separator())
        notchItem.target = self
        notchItem.action = #selector(toggleNotch)
        submenu.addItem(notchItem.symbol("rectangle.topthird.inset.filled"))
        notchNote.isEnabled = false
        submenu.addItem(notchNote.symbol("info.circle"))
        menuItem.submenu = submenu
        menuItem.symbol("menubar.dock.rectangle")

        displays.onScreenConfigurationChanged = { [weak self] in self?.refresh() }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification,
                     NSWorkspace.activeSpaceDidChangeNotification,
                     NSWorkspace.didWakeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.refresh()
            })
        }
        // Dark Mode on/off changes the menu bar's text colour.
        appearanceObservation = NSApp?.observe(\.effectiveAppearance) { [weak self] _, _ in
            DispatchQueue.main.async { self?.refresh() }
        }
        refresh()
    }

    deinit {
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }

    func menuWillOpen() { refresh() }

    func shutdown() {
        isShutDown = true
        surfaces.values.forEach { $0.close() }
        surfaces.removeAll()
    }

    // MARK: - Menu

    @objc private func toggleCurtain() {
        curtainOn.toggle()
        refresh()
    }

    @objc private func toggleNotch() {
        notchOn.toggle()
        refresh()
    }

    @objc private func chooseStyle(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String else { return }
        style = CurtainStyle.saved(raw)
        refresh()
    }

    private func updateMenu() {
        curtainItem.state = curtainOn ? .on : .off
        notchItem.state = notchOn ? .on : .off
        menuItem.state = (curtainOn || notchOn) ? .on : .off
        for item in styleMenu.items {
            item.state = (item.representedObject as? String) == style.rawValue ? .on : .off
        }
        wallpaperNote.isHidden = !(curtainOn && style == .wallpaper
                                   && surfaces.values.contains { $0.wallpaperUnreadable })
        if notchOn && !anyNotch {
            notchNote.title = "No display here has a notch"
            notchNote.isHidden = false
        } else if notchOn && notchPaused {
            notchNote.title = "Paused — the menu bar is drawing dark text"
            notchNote.isHidden = false
        } else {
            notchNote.isHidden = true
        }
    }

    // MARK: - Drawing

    /// Bring every screen's window in line with the switches. Cheap when
    /// nothing changed: windows are only moved if their frame differs, and
    /// a wallpaper is only decoded when its file, options or size do.
    private func refresh() {
        // Quitting: a late notification must not put a window back up.
        guard !isShutDown else { return }
        let lightText = DesktopLayout.menuBarDrawsLightText(menuBarAppearance() ?? NSApp?.effectiveAppearance)
        anyNotch = false
        notchPaused = false
        var present = Set<CGDirectDisplayID>()

        for screen in NSScreen.screens {
            let id = ScreenGeometry.displayID(of: screen)
            present.insert(id)
            let housing = DesktopLayout.hasCameraHousing(safeAreaTop: screen.safeAreaInsets.top,
                                                         auxiliaryLeft: screen.auxiliaryTopLeftArea,
                                                         auxiliaryRight: screen.auxiliaryTopRightArea)
            anyNotch = anyNotch || housing
            if notchOn && housing && !lightText { notchPaused = true }
            let band = (notchOn && housing && lightText)
                ? DesktopLayout.bandRect(screenFrame: screen.frame, visibleFrame: screen.visibleFrame,
                                         safeAreaTop: screen.safeAreaInsets.top)
                : nil
            guard let frame = DesktopLayout.windowFrame(screenFrame: screen.frame,
                                                        curtain: curtainOn, band: band) else {
                surfaces[id]?.close()
                surfaces[id] = nil
                continue
            }
            let surface = surfaces[id] ?? DesktopSurface(frame: frame)
            surfaces[id] = surface
            surface.layout(frame: frame, screen: screen, curtain: curtainOn ? style : nil, band: band) { [weak self] in
                // A decode finished: the unreadable note may have changed.
                self?.updateMenu()
            }
        }
        for (id, surface) in surfaces where !present.contains(id) {
            surface.close()
            surfaces[id] = nil
        }
        updateMenu()
    }
}

/// One screen's desktop-level window: the curtain layer (wallpaper or a
/// plain colour) and, above it, the black notch band.
private final class DesktopSurface {
    private let window: PassiveOverlayWindow
    private let curtain = CALayer()
    private let band = CALayer()
    /// What the curtain currently shows (or is decoding), so an unchanged
    /// refresh does not decode the wallpaper again.
    private var wallpaperKey: WallpaperKey?
    private var generation = 0
    private(set) var wallpaperUnreadable = false

    private struct WallpaperKey: Equatable {
        let url: URL?
        let gravity: CALayerContentsGravity
        let pixels: CGSize
    }

    init(frame: NSRect) {
        // .stationary: Mission Control leaves it where it is, like the
        // desktop picture it stands in for. No .fullScreenAuxiliary: there is
        // no desktop to cover in a full-screen app's Space.
        window = PassiveOverlayWindow(frame: frame, level: OverlayLevel.desktop,
                                      behavior: [.canJoinAllSpaces, .stationary, .ignoresCycle])
        band.backgroundColor = NSColor.black.cgColor
        window.rootLayer.addSublayer(curtain)
        window.rootLayer.addSublayer(band)
    }

    func layout(frame: NSRect, screen: NSScreen, curtain style: DesktopTool.CurtainStyle?, band bandRect: CGRect?,
                decoded: @escaping () -> Void) {
        window.place(frame)
        let scale = screen.backingScaleFactor
        OverlayDrawing.withoutAnimation {
            curtain.isHidden = style == nil
            curtain.frame = ScreenGeometry.local(screen.frame, in: frame)
            curtain.contentsScale = scale
            band.isHidden = bandRect == nil
            if let bandRect {
                band.frame = ScreenGeometry.local(bandRect, in: frame)
            }
        }
        if let style {
            fill(style, screen: screen, scale: scale, decoded: decoded)
        } else {
            forgetWallpaper()
        }
        window.show()
    }

    private func fill(_ style: DesktopTool.CurtainStyle, screen: NSScreen, scale: CGFloat,
                      decoded: @escaping () -> Void) {
        if let color = style.color {
            forgetWallpaper()
            OverlayDrawing.withoutAnimation {
                curtain.backgroundColor = color.cgColor
            }
            return
        }
        let url = NSWorkspace.shared.desktopImageURL(for: screen)
        let options = NSWorkspace.shared.desktopImageOptions(for: screen)
        let gravity = DesktopLayout.gravity(options: options)
        let pixels = CGSize(width: screen.frame.width * scale, height: screen.frame.height * scale)
        let fillColor = (options?[.fillColor] as? NSColor)?.usingColorSpace(.sRGB) ?? .black
        OverlayDrawing.withoutAnimation {
            curtain.contentsGravity = gravity
            curtain.backgroundColor = fillColor.cgColor
        }
        let key = WallpaperKey(url: url, gravity: gravity, pixels: pixels)
        guard key != wallpaperKey else { return }
        wallpaperKey = key
        generation &+= 1
        let ticket = generation
        guard let url else {
            showWallpaper(nil, decoded: decoded)
            return
        }
        // Off the main thread: a 6K HEIC takes a noticeable moment to decode,
        // even downsampled. The previous image stays up until this lands.
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let image = DesktopLayout.loadWallpaper(url: url, screenPixels: pixels, gravity: gravity)
            DispatchQueue.main.async {
                guard let self, self.generation == ticket else { return }
                self.showWallpaper(image, decoded: decoded)
            }
        }
    }

    /// nil: the file could not be read. The likely cause is the sandbox: a
    /// photo in the user's own folders is outside what the app may read
    /// without a new entitlement. (The system's wallpapers live under
    /// /System and are expected to be readable — unverified in the sandboxed
    /// build.) The wallpaper's fill colour stands in.
    private func showWallpaper(_ image: CGImage?, decoded: () -> Void) {
        wallpaperUnreadable = image == nil
        OverlayDrawing.withoutAnimation {
            curtain.contents = image
        }
        decoded()
    }

    private func forgetWallpaper() {
        wallpaperKey = nil
        wallpaperUnreadable = false
        generation &+= 1
        OverlayDrawing.withoutAnimation {
            curtain.contents = nil
        }
    }

    func close() {
        generation &+= 1
        window.orderOut(nil)
        window.close()
    }
}

/// The Desktop tool's decisions, pure and unit-tested (DesktopToolTests).
enum DesktopLayout {
    // MARK: Window

    /// The window covers the whole screen when the curtain is on, only the
    /// notch band when that is all there is to draw, and does not exist
    /// otherwise — no full-screen transparent window kept around for a band.
    static func windowFrame(screenFrame: CGRect, curtain: Bool, band: CGRect?) -> CGRect? {
        if curtain { return screenFrame }
        return band
    }

    // MARK: Notch

    /// A camera housing: macOS reports an obscured strip at the top of the
    /// screen and/or the unobscured areas either side of the housing.
    static func hasCameraHousing(safeAreaTop: CGFloat, auxiliaryLeft: CGRect?, auxiliaryRight: CGRect?) -> Bool {
        safeAreaTop > 0
            || !(auxiliaryLeft ?? .zero).isEmpty
            || !(auxiliaryRight ?? .zero).isEmpty
    }

    /// The strip to paint black, in AppKit global coordinates: the full width
    /// of the screen, as tall as the menu bar or the housing, whichever is
    /// taller. (With the menu bar set to hide itself, `visibleFrame` reaches
    /// the top and the housing's height is what is left.)
    static func bandRect(screenFrame: CGRect, visibleFrame: CGRect, safeAreaTop: CGFloat) -> CGRect? {
        let menuBar = max(0, screenFrame.maxY - visibleFrame.maxY)
        let height = min(screenFrame.height, max(safeAreaTop, menuBar))
        guard height > 0 else { return nil }
        return CGRect(x: screenFrame.minX, y: screenFrame.maxY - height,
                      width: screenFrame.width, height: height)
    }

    /// Whether the menu bar is drawing light text (dark appearance). nil
    /// appearance → false: never paint black under text of unknown colour.
    static func menuBarDrawsLightText(_ appearance: NSAppearance?) -> Bool {
        guard let appearance else { return false }
        let match = appearance.bestMatch(from: [.aqua, .darkAqua, .vibrantLight, .vibrantDark])
        return match == .darkAqua || match == .vibrantDark
    }

    // MARK: Wallpaper

    /// How macOS lays the wallpaper out, as a layer gravity. Per NSWorkspace.h:
    /// no scaling key means proportional; no clipping key means "fit" (no
    /// clipping); proportionally-down is "not currently supported" and is
    /// treated as up-or-down.
    ///
    /// No options at all — nil *or an empty dictionary* — is Fill Screen.
    /// macOS 26.6 returns `[:]` for a system wallpaper (measured 2026-11-22,
    /// a 3840×2160 image on a 16:10 panel); read by the header's defaults
    /// that would be "fit", and the curtain would be letterboxed where the
    /// real desktop is not.
    static func gravity(options: [NSWorkspace.DesktopImageOptionKey: Any]?) -> CALayerContentsGravity {
        guard let options, !options.isEmpty else { return .resizeAspectFill }
        let scaling = (options[.imageScaling] as? NSNumber)
            .flatMap { NSImageScaling(rawValue: $0.uintValue) } ?? .scaleProportionallyUpOrDown
        switch scaling {
        case .scaleAxesIndependently:
            return .resize
        case .scaleNone:
            return .center
        default:
            let clipping = (options[.allowClipping] as? NSNumber)?.boolValue ?? false
            return clipping ? .resizeAspectFill : .resizeAspect
        }
    }

    /// The longest side, in pixels, to decode the wallpaper at: enough to
    /// cover the screen's pixels as `gravity` lays it out, never more than
    /// the file has. A 6K wallpaper decoded whole is ~140 MB per screen.
    static func decodeMaxPixelSize(image: CGSize, screen: CGSize, gravity: CALayerContentsGravity) -> Int {
        guard image.width > 0, image.height > 0, screen.width > 0, screen.height > 0 else { return 0 }
        let fitX = screen.width / image.width
        let fitY = screen.height / image.height
        let scale: CGFloat
        switch gravity {
        case .resizeAspect: scale = min(fitX, fitY)
        case .center: scale = 1
        default: scale = max(fitX, fitY)   // fill, stretch
        }
        // Round up, but not past an exact fit that floating point overshot.
        return Int((max(image.width, image.height) * min(scale, 1) - 1e-6).rounded(.up))
    }

    /// Decodes the wallpaper file downsampled for the screen. nil when the
    /// file cannot be opened (sandbox, a bundle rather than an image, gone).
    /// For a multi-image HEIC (dynamic wallpaper) this is the primary image,
    /// which is not necessarily the one macOS is showing at this hour.
    static func loadWallpaper(url: URL, screenPixels: CGSize, gravity: CALayerContentsGravity) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue else {
            return nil
        }
        // EXIF orientations 5–8 are rotated a quarter turn: the thumbnail
        // comes out with width and height swapped.
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        let size = (5...8).contains(orientation) ? CGSize(width: height, height: width)
                                                 : CGSize(width: width, height: height)
        let maxPixels = decodeMaxPixelSize(image: size, screen: screenPixels, gravity: gravity)
        guard maxPixels > 0 else { return nil }
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary)
    }
}
