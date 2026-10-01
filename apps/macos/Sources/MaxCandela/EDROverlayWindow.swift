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
        let rect = Self.patchFrame(on: screen)
        let size = Self.patchSize

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

    /// Bottom-right corner of `screen`, in global coordinates.
    private static func patchFrame(on screen: NSScreen) -> NSRect {
        NSRect(x: screen.frame.maxX - patchSize, y: screen.frame.minY,
               width: patchSize, height: patchSize)
    }

    /// Re-park on `screen` after a resolution or arrangement change. The frame
    /// is global, so the screen can move out from under it — and off its
    /// display the patch holds no EDR open. A no-op when nothing moved.
    func place(on screen: NSScreen) {
        let rect = Self.patchFrame(on: screen)
        if frame != rect {
            setFrame(rect, display: false)
        }
        let scale = screen.backingScaleFactor
        let drawable = CGSize(width: Self.patchSize * scale, height: Self.patchSize * scale)
        if renderer.metalLayer.drawableSize != drawable {
            renderer.metalLayer.drawableSize = drawable
        }
    }

    /// Trigger windows should never become key/main — they're passive.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func activate() {
        // Order on screen first so the hosting view has a window/screen for its
        // display link, then start the render loop from that view.
        orderFrontRegardless()
        if let view = contentView {
            renderer.start(view: view)
        }
    }

    func deactivate() {
        renderer.stop()
        orderOut(nil)
    }
}
