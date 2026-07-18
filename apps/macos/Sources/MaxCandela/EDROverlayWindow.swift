import AppKit

/// A tiny (few-pixel) borderless, click-through window parked in the corner of
/// one screen. It hosts the EDR `CAMetalLayer` whose only job is to keep the
/// compositor in EDR mode so the display's HDR headroom stays engaged — the
/// actual screen-wide brightening comes from GammaController's lift.
///
/// It must never intercept input or vanish in fullscreen — hence the window
/// level, collection behavior, and `ignoresMouseEvents` below.
final class EDROverlayWindow: NSWindow {
    /// Side length of the trigger patch in points. Small enough to be
    /// effectively invisible, large enough that the compositor doesn't cull it.
    static let patchSize: CGFloat = 4

    let renderer: MetalRenderer

    /// Returns nil if Metal is unavailable on this machine (see MetalRenderer).
    init?(screen: NSScreen) {
        guard let renderer = MetalRenderer() else { return nil }
        self.renderer = renderer

        // Bottom-right corner of the target screen.
        let size = Self.patchSize
        let rect = NSRect(
            x: screen.frame.maxX - size,
            y: screen.frame.minY,
            width: size,
            height: size
        )

        // Note: use the base designated initializer, not the `screen:` variant.
        // On newer macOS the screen: variant delegates to this one on `self`,
        // which traps in Swift subclasses ("unimplemented initializer"). The
        // rect is in global screen coordinates, so no screen hint is needed.
        super.init(
            contentRect: rect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true            // click-through
        level = .screenSaver                 // above normal content
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        let hosting = NSView(frame: NSRect(origin: .zero, size: rect.size))
        hosting.wantsLayer = true
        renderer.metalLayer.frame = hosting.bounds
        renderer.metalLayer.drawableSize = CGSize(
            width: size * (screen.backingScaleFactor),
            height: size * (screen.backingScaleFactor)
        )
        hosting.layer = renderer.metalLayer
        contentView = hosting
    }

    /// Trigger windows should never become key/main — they're passive.
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
