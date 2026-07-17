import AppKit

/// A borderless, transparent, click-through window covering one screen. It hosts
/// the EDR `CAMetalLayer` that primes the display's HDR headroom. It must never
/// intercept input or vanish in fullscreen — hence the window level, collection
/// behavior, and `ignoresMouseEvents` below.
final class EDROverlayWindow: NSWindow {
    let renderer: MetalRenderer

    /// Returns nil if Metal is unavailable on this machine (see MetalRenderer).
    init?(screen: NSScreen) {
        guard let renderer = MetalRenderer() else { return nil }
        self.renderer = renderer

        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true            // click-through
        level = .screenSaver                 // above normal content
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        // Low alpha: we prime EDR headroom rather than paint an opaque sheet.
        // BrightnessController tunes this alongside boost. See CLAUDE.md (MVP).
        alphaValue = 0.0

        let hosting = NSView(frame: screen.frame)
        hosting.wantsLayer = true
        renderer.metalLayer.frame = hosting.bounds
        hosting.layer = renderer.metalLayer
        contentView = hosting
    }

    /// Overlay windows should never become key/main — they're passive.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func activate() {
        renderer.start()
        orderFrontRegardless()
    }

    func deactivate() {
        renderer.stop()
        orderOut(nil)
    }
}
