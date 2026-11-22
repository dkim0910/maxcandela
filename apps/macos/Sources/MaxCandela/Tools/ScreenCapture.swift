import AppKit
import ScreenCaptureKit

/// A captured image and how many of its pixels make one point on the display
/// it came from (2 on a Retina panel). Kept together because everything
/// downstream — the editor's natural size, stroke widths, the PNG's DPI —
/// needs both.
struct ScreenImage {
    let image: CGImage
    let pixelsPerPoint: CGFloat
}

/// A window the user can pick for a single-window capture, as the window
/// server lists it. `frame` is in CoreGraphics global coordinates (origin at
/// the top-left of the primary display, y down), in points.
struct PickableWindow: Equatable {
    let id: CGWindowID
    let frame: CGRect
}

/// Everything the screen tools (Screenshot, Copy Text from Screen) share
/// about looking at the screen: the Screen Recording permission, the
/// coordinate conversions, and the ScreenCaptureKit calls.
///
/// Coordinate systems in play — most capture bugs are a mix-up between them:
///  - **AppKit global**: `NSScreen.frame`, `NSEvent.mouseLocation`. Origin at
///    the bottom-left of the primary display, y up, points.
///  - **CoreGraphics global**: `CGWindowListCopyWindowInfo` bounds,
///    `SCWindow.frame`. Origin at the top-left of the primary display, y
///    down, points.
///  - **Display-local**: `SCStreamConfiguration.sourceRect`. Origin at the
///    top-left of *that* display, y down, points.
///  - **Pixels**: `SCStreamConfiguration.width/height` and the image itself.
///    Points × `SCContentFilter.pointPixelScale`.
/// The pure functions below convert between them and are unit-tested.
///
/// ⚠️ The capture calls are not exercised during development (the dev binary
/// has no Screen Recording grant); only the arithmetic is tested.
enum ScreenCapture {

    // MARK: - Permission

    private static let askedKey = "com.maxcandela.screenRecording.asked"

    /// True if the app may capture the screen. Otherwise asks: the first time
    /// with the system's own prompt; after that — when macOS no longer shows
    /// one and a click would otherwise do nothing at all — with an alert that
    /// says where the switch is.
    static func ensureAccess() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: askedKey) {
            defaults.set(true, forKey: askedKey)
            CGRequestScreenCaptureAccess()
            return false
        }
        explainMissingAccess()
        return false
    }

    private static func explainMissingAccess() {
        let alert = NSAlert()
        alert.messageText = "MaxCandela can’t see the screen"
        alert.informativeText = """
        To capture the screen, turn on MaxCandela in System Settings ▸ Privacy & Security ▸ Screen & System Audio Recording.

        macOS may ask you to quit and reopen MaxCandela afterwards. Only what you select is captured, and it never leaves your Mac.
        """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn,
              let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Geometry (pure, unit-tested)

    /// A selection in AppKit global coordinates → the same box relative to
    /// its display with the origin top-left and y down, which is what
    /// `sourceRect` wants. Clipped to the display: a drag that wanders onto
    /// a neighbouring screen keeps reporting points outside this one.
    static func captureRect(selection: CGRect, screenFrame: CGRect) -> CGRect {
        let inside = selection.intersection(screenFrame)
        guard !inside.isNull else { return .zero }
        return CGRect(x: inside.minX - screenFrame.minX,
                      y: screenFrame.maxY - inside.maxY,
                      width: inside.width, height: inside.height)
    }

    /// Grows a rectangle in points outward to the nearest whole pixels.
    /// Mouse positions on a Retina display land on half points, and a
    /// `sourceRect` that splits pixels is resampled — soft text — while
    /// truncating `width * scale` to an Int would also drop the last column.
    static func pixelAligned(_ rect: CGRect, scale: CGFloat) -> CGRect {
        guard scale > 0, !rect.isEmpty else { return rect }
        let minX = (rect.minX * scale).rounded(.down) / scale
        let minY = (rect.minY * scale).rounded(.down) / scale
        let maxX = (rect.maxX * scale).rounded(.up) / scale
        let maxY = (rect.maxY * scale).rounded(.up) / scale
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// The output size in pixels for a pixel-aligned rect in points.
    static func pixelSize(of rect: CGRect, scale: CGFloat) -> (width: Int, height: Int) {
        (Int((rect.width * scale).rounded()), Int((rect.height * scale).rounded()))
    }

    /// Which of `frames` (AppKit global) holds `point`. Edges count: the
    /// pointer pinned to the top of the screen reports y == maxY, which a
    /// plain `contains` (half-open) would place on no screen at all.
    static func screenIndex(containing point: CGPoint, in frames: [CGRect]) -> Int? {
        if let index = frames.firstIndex(where: { $0.contains(point) }) { return index }
        return frames.firstIndex { frame in
            point.x >= frame.minX && point.x <= frame.maxX && point.y >= frame.minY && point.y <= frame.maxY
        }
    }

    /// AppKit global → CoreGraphics global. Both are anchored to the primary
    /// display (the one at index 0 of `NSScreen.screens`), so only y flips.
    static func cgPoint(fromAppKit point: CGPoint, primaryHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    /// CoreGraphics global → AppKit global, for a rectangle.
    static func appKitRect(fromCG rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Ordinary windows of other apps, front to back, from the window
    /// server's list. Skips the desktop, the Dock and everything layered above
    /// it (menu bar, status items, menus), invisible windows, slivers, and
    /// our own windows (the overlay the user is picking with, open editors).
    static func pickableWindows(from info: [[String: Any]], excludingPID: pid_t) -> [PickableWindow] {
        info.compactMap { entry in
            guard let number = entry[kCGWindowNumber as String] as? Int,
                  let layer = entry[kCGWindowLayer as String] as? Int,
                  (0..<Int(CGWindowLevelForKey(.dockWindow))).contains(layer),
                  (entry[kCGWindowOwnerPID as String] as? Int).map({ pid_t($0) }) != excludingPID,
                  (entry[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                  let bounds = entry[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds),
                  frame.width >= 20, frame.height >= 20
            else { return nil }
            return PickableWindow(id: CGWindowID(number), frame: frame)
        }
    }

    /// The window the pointer is over: the first, front to back, containing
    /// it. `point` is CoreGraphics global.
    static func frontmost(at point: CGPoint, in windows: [PickableWindow]) -> PickableWindow? {
        windows.first { $0.frame.contains(point) }
    }

    // MARK: - Live system state

    static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    /// The screen the pointer is on, else the main one.
    static func screenUnderPointer() -> NSScreen? {
        let screens = NSScreen.screens
        let index = screenIndex(containing: NSEvent.mouseLocation, in: screens.map(\.frame))
        return index.map { screens[$0] } ?? NSScreen.main ?? screens.first
    }

    /// Height of the primary display — the reference for every y flip.
    static var primaryHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }

    /// What `pickableWindows(from:)` sees right now. Bounds need no
    /// permission (only window *titles* do, and they are not read).
    static func onScreenWindows() -> [PickableWindow] {
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        return pickableWindows(from: info, excludingPID: ProcessInfo.processInfo.processIdentifier)
    }

    // MARK: - Capture

    enum Failure: Error { case displayGone, windowGone, emptySelection }

    /// A box the user drew, in AppKit global coordinates, on `screen`.
    static func region(_ selection: CGRect, on screen: NSScreen) async throws -> ScreenImage {
        let local = captureRect(selection: selection, screenFrame: screen.frame)
        guard local.width >= 1, local.height >= 1 else { throw Failure.emptySelection }
        return try await capture(on: screen, sourceRect: local)
    }

    /// The whole of `screen`.
    static func display(_ screen: NSScreen) async throws -> ScreenImage {
        try await capture(on: screen, sourceRect: nil)
    }

    /// One window on its own, wherever it is and whatever covers it.
    static func window(_ id: CGWindowID) async throws -> ScreenImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let window = content.windows.first(where: { $0.windowID == id }) else { throw Failure.windowGone }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let scale = CGFloat(filter.pointPixelScale)
        let configuration = baseConfiguration()
        // A cut-out of the window itself; the drop shadow would add a wide
        // transparent margin to crop, pixelate and paste around. Sized from
        // the window's own frame, which has no shadow in it: if that is ever
        // smaller than what the filter delivers, the output scales down a
        // touch, where a shadow-sized canvas would leave an empty margin.
        configuration.ignoreShadowsSingleWindow = true
        let pixels = pixelSize(of: CGRect(origin: .zero, size: window.frame.size), scale: scale)
        configuration.width = pixels.width
        configuration.height = pixels.height
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        return ScreenImage(image: image, pixelsPerPoint: scale)
    }

    private static func capture(on screen: NSScreen, sourceRect: CGRect?) async throws -> ScreenImage {
        guard let displayID = displayID(of: screen) else { throw Failure.displayGone }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw Failure.displayGone
        }
        let filter = displayFilter(display, content: content)
        let scale = CGFloat(filter.pointPixelScale)
        let configuration = baseConfiguration()
        let rect = pixelAligned(sourceRect ?? CGRect(x: 0, y: 0, width: display.width, height: display.height),
                                scale: scale)
        if sourceRect != nil { configuration.sourceRect = rect }
        let pixels = pixelSize(of: rect, scale: scale)
        configuration.width = pixels.width
        configuration.height = pixels.height
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        return ScreenImage(image: image, pixelsPerPoint: scale)
    }

    private static func baseConfiguration() -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        configuration.showsCursor = false
        configuration.captureResolution = .best
        return configuration
    }

    /// The display without our own windows — the selection overlay, a
    /// closing menu, open editors — so nothing of ours has to have finished
    /// leaving the screen before the shot. Our status items stay: a capture
    /// of the menu bar should look like the menu bar.
    private static func displayFilter(_ display: SCDisplay, content: SCShareableContent) -> SCContentFilter {
        let pid = ProcessInfo.processInfo.processIdentifier
        guard let us = content.applications.first(where: { $0.processID == pid }) else {
            return SCContentFilter(display: display, excludingWindows: [])
        }
        let statusLevel = Int(CGWindowLevelForKey(.statusWindow))
        let statusItems = content.windows.filter {
            $0.owningApplication?.processID == pid && $0.windowLayer == statusLevel
        }
        return SCContentFilter(display: display, excludingApplications: [us], exceptingWindows: statusItems)
    }
}
