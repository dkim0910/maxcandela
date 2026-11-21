import AppKit
import ScreenCaptureKit
import Vision

/// Copy Text from Screen (Pro): drag a box over anything — a video frame, a
/// PDF that won't select, an image, a dialog — and the text in it lands on
/// the clipboard. Recognition is Apple's on-device Vision framework; the
/// captured image is discarded as soon as it has been read and nothing leaves
/// the Mac.
///
/// Needs the Screen Recording permission (System Settings ▸ Privacy &
/// Security ▸ Screen & System Audio Recording), requested on first use. This
/// is the only place the app looks at the screen at all, and only at the box
/// the user draws — say so in /privacy if this text changes.
///
/// ⚠️ Not exercised at runtime during development (no Screen Recording grant
/// for the dev binary). The rectangle maths and text joining are unit-tested;
/// the capture and the overlay are not.
final class ScreenTextTool: MenuTool {
    let menuItem = NSMenuItem(title: "Copy Text from Screen…", action: nil, keyEquivalent: "")
    var onStatusChange: (() -> Void)?
    var isPro: Bool { true }

    private var overlays: [RegionSelectionWindow] = []

    init() {
        menuItem.target = self
        menuItem.action = #selector(begin)
        menuItem.symbol("text.viewfinder")
    }

    func shutdown() { closeOverlays() }

    /// Pure, unit-tested. A selection in AppKit global coordinates (origin
    /// bottom-left, y up) → the same box relative to its display with the
    /// origin top-left and y down, which is what ScreenCaptureKit wants.
    static func captureRect(selection: CGRect, screenFrame: CGRect) -> CGRect {
        CGRect(x: selection.minX - screenFrame.minX,
               y: screenFrame.maxY - selection.maxY,
               width: selection.width, height: selection.height)
    }

    /// Pure, unit-tested. Lines in reading order, blanks dropped.
    static func join(lines: [String]) -> String {
        lines.map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    @objc private func begin() {
        guard CGPreflightScreenCaptureAccess() else {
            // Shows the system prompt the first time; afterwards it is a
            // no-op and the user has to flip the switch in System Settings.
            CGRequestScreenCaptureAccess()
            return
        }
        closeOverlays()
        NSApp.activate(ignoringOtherApps: true)
        for screen in NSScreen.screens {
            let window = RegionSelectionWindow(screen: screen) { [weak self] selection in
                self?.closeOverlays()
                guard let selection, selection.width > 4, selection.height > 4 else { return }
                self?.capture(selection, on: screen)
            }
            overlays.append(window)
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func closeOverlays() {
        overlays.forEach { $0.orderOut(nil) }
        overlays.removeAll()
    }

    private func capture(_ selection: CGRect, on screen: NSScreen) {
        let displayID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) ?? 0
        let rect = Self.captureRect(selection: selection, screenFrame: screen.frame)
        let scale = screen.backingScaleFactor
        Task {
            do {
                // A beat for the overlay to leave the screen before the shot.
                try await Task.sleep(nanoseconds: 120_000_000)
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first(where: { $0.displayID == displayID }) else { return }
                let configuration = SCStreamConfiguration()
                configuration.sourceRect = rect
                configuration.width = Int(rect.width * scale)
                configuration.height = Int(rect.height * scale)
                configuration.showsCursor = false
                let image = try await SCScreenshotManager.captureImage(
                    contentFilter: SCContentFilter(display: display, excludingWindows: []),
                    configuration: configuration)
                let text = try Self.recognise(image)
                await MainActor.run {
                    guard !text.isEmpty else {
                        NSSound.beep()
                        return
                    }
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    NSSound(named: "Pop")?.play()
                }
            } catch {
                NSLog("MaxCandela: screen text capture failed: \(error.localizedDescription)")
                await MainActor.run { NSSound.beep() }
            }
        }
    }

    private static func recognise(_ image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        return join(lines: lines)
    }
}

/// A dimmed, full-screen window on which the user drags out a rectangle.
/// Escape, or a click without a drag, cancels.
final class RegionSelectionWindow: NSWindow {
    private let onFinish: (CGRect?) -> Void

    init(screen: NSScreen, onFinish: @escaping (CGRect?) -> Void) {
        self.onFinish = onFinish
        // Base designated init with global coordinates — the screen: variant
        // traps in subclasses on newer macOS (see CLAUDE.md gotchas).
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let view = RegionSelectionView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.onFinish = { [weak self] local in
            guard let self else { return }
            // View coordinates → global AppKit coordinates.
            self.onFinish(local.map { $0.offsetBy(dx: self.frame.minX, dy: self.frame.minY) })
        }
        contentView = view
    }

    // A borderless window refuses key status by default, and without it the
    // Escape key never arrives.
    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) { onFinish(nil) }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onFinish(nil) } else { super.keyDown(with: event) }
    }
}

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
    }

    override func mouseDown(with event: NSEvent) {
        start = convert(event.locationInWindow, from: nil)
        selection = nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start else { return }
        let point = convert(event.locationInWindow, from: nil)
        selection = CGRect(x: min(start.x, point.x), y: min(start.y, point.y),
                           width: abs(point.x - start.x), height: abs(point.y - start.y))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        onFinish?(selection)
        start = nil
        selection = nil
    }
}
