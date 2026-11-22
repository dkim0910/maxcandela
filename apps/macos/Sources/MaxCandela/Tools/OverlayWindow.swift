import AppKit

/// The window levels the overlay tools use, kept together so the ordering
/// they rely on is written down once and tested (OverlayGeometryTests):
///
///     desktop picture < Finder's desktop icons < `desktop`
///       < every app's normal windows < `dimmer`
///       < floating panels, alerts, the Dock, the menu bar, menus
///       < the EDR trigger (`EDROverlayWindow.windowLevel`)
///
/// Both must stay below the EDR trigger. The trigger is a 4×4 patch of EDR
/// white that keeps the panel in HDR mode; a dark full-screen layer over it
/// would dim exactly the pixels the boost depends on.
enum OverlayLevel {
    /// One above Finder's desktop icons: hides them, and sits under every
    /// window any app can open.
    static let desktop = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)

    /// One above normal app windows. Everything an app shows *outside* its
    /// normal windows — menus, popovers above layer 0, floating palettes,
    /// alerts, tooltips — is higher still, so the dimmer can never darken it.
    static let dimmer = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue + 1)
}

/// A borderless window that only ever shows something: no shadow, no focus,
/// no clicks (they fall through to whatever is underneath), not in the
/// window cycle. Its content view hosts a plain `CALayer` tree — the tools
/// draw with layers, never with `draw(_:)`, so a redraw is a property change
/// the compositor applies rather than a full-screen bitmap re-upload.
///
/// Like `EDROverlayWindow`, it uses the base designated initializer: the
/// `screen:` variant traps in Swift subclasses on newer macOS.
final class PassiveOverlayWindow: NSWindow {
    let rootLayer = CALayer()

    init(frame: NSRect, level: NSWindow.Level, behavior: NSWindow.CollectionBehavior) {
        super.init(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true            // click-through
        isReleasedWhenClosed = false
        animationBehavior = .none
        hidesOnDeactivate = false
        self.level = level
        collectionBehavior = behavior

        // Layer-hosting (layer assigned before wantsLayer): AppKit leaves the
        // sublayers to us.
        let host = NSView(frame: NSRect(origin: .zero, size: frame.size))
        host.layer = rootLayer
        host.wantsLayer = true
        host.autoresizingMask = [.width, .height]
        contentView = host
        OverlayDrawing.withoutAnimation {
            rootLayer.frame = host.bounds
        }
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Move to `rect` (global AppKit coordinates). A no-op when nothing moved.
    func place(_ rect: NSRect) {
        guard frame != rect else { return }
        setFrame(rect, display: false)
        OverlayDrawing.withoutAnimation {
            rootLayer.frame = NSRect(origin: .zero, size: rect.size)
        }
    }

    func show() {
        if !isVisible { orderFrontRegardless() }
    }
}

enum OverlayDrawing {
    /// Core Animation animates property changes on free-standing layers by
    /// default. A hole that slides after its window, or a wallpaper that
    /// cross-fades on a Space switch, reads as lag — every overlay change is
    /// applied in one frame.
    static func withoutAnimation(_ body: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        body()
        CATransaction.commit()
    }
}

/// Coordinate conversions the overlays need. Pure, unit-tested.
///
/// Two global spaces are in play. **Quartz** (window-server bounds from
/// `CGWindowListCopyWindowInfo`): origin at the top-left of the *primary*
/// display, y grows downward. **AppKit** (`NSScreen.frame`, `NSWindow.frame`):
/// origin at the bottom-left of the primary display, y grows upward. Other
/// displays sit anywhere around the primary in both, including at negative
/// coordinates.
enum ScreenGeometry {
    /// Quartz global rect → AppKit global rect.
    static func appKitRect(fromQuartz rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryScreenHeight - rect.maxY,
               width: rect.width, height: rect.height)
    }

    /// AppKit global rect → the same rect relative to a screen's bottom-left
    /// corner, i.e. in the coordinates of a window covering that screen.
    static func local(_ rect: CGRect, in screenFrame: CGRect) -> CGRect {
        rect.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY)
    }

    /// The height Quartz measures from: the primary display is the one whose
    /// AppKit frame starts at the origin (`NSScreen.screens.first`, the one
    /// with the menu bar). Nil with no screens at all.
    static func primaryScreenHeight(_ frames: [CGRect]) -> CGFloat? {
        (frames.first { $0.origin == .zero } ?? frames.first)?.height
    }

    static func displayID(of screen: NSScreen) -> CGDirectDisplayID {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) ?? 0
    }
}
