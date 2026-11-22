import AppKit

/// The 20-second "look away" reminder: a small panel near the top of the
/// screen the user is on, with a countdown, Skip and Snooze. It closes by
/// itself when the countdown ends.
///
/// It must never take focus: whatever the user is typing keeps going to the
/// app they are typing in. Three things together guarantee that — a
/// `.nonactivatingPanel` (clicking it does not activate MaxCandela), a panel
/// that refuses key and main status, and `orderFrontRegardless()` instead of
/// `makeKeyAndOrderFront`. The buttons accept the first click, so Skip works
/// without a click to "focus" the panel first.
final class BreakPanel: NSObject {
    var onFinish: (() -> Void)?
    var onSkip: (() -> Void)?
    var onSnooze: (() -> Void)?

    static let message = "Time for a break: look at something 20 feet away"
    private static let width: CGFloat = 380
    /// Gap between the menu bar (top of the visible frame) and the panel.
    private static let topInset: CGFloat = 12

    private let panel: ReminderPanel
    private let countdown = NSTextField(labelWithString: "")
    private let snoozeButton = FirstClickButton(title: "Snooze", target: nil, action: nil)
    private var secondsLeft = 0
    private var ticker: Timer?

    override init() {
        panel = ReminderPanel(contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 96),
                              styleMask: [.nonactivatingPanel, .borderless],
                              backing: .buffered, defer: true)
        super.init()

        panel.level = .statusBar
        // Over full-screen apps too, on whichever Space is showing, and out
        // of ⌘` / window cycling.
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isFloatingPanel = true
        // NSPanel hides when its app deactivates — and this app is never
        // active, so without this the reminder would vanish at once.
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true

        let background = NSVisualEffectView()
        background.material = .popover
        // .active: the panel is never key, and the default "follows window
        // state" would draw it in the washed-out inactive style.
        background.state = .active
        background.blendingMode = .behindWindow
        background.maskImage = Self.roundedMask(radius: 12)

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "eye", accessibilityDescription: nil)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        icon.contentTintColor = .controlAccentColor
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let text = NSTextField(wrappingLabelWithString: Self.message)
        text.font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        text.preferredMaxLayoutWidth = Self.width - 80

        countdown.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        countdown.textColor = .secondaryLabelColor

        let skip = FirstClickButton(title: "Skip", target: self, action: #selector(skip))
        snoozeButton.target = self
        snoozeButton.action = #selector(snooze)
        for button in [skip, snoozeButton] {
            button.bezelStyle = .rounded
            button.controlSize = .small
            button.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            // Return/Escape would need key focus, which this panel never has.
            button.keyEquivalent = ""
        }

        let top = NSStackView(views: [icon, text])
        top.orientation = .horizontal
        top.alignment = .centerY
        top.spacing = 12
        let bottom = NSStackView(views: [countdown, NSView(), skip, snoozeButton])
        bottom.orientation = .horizontal
        bottom.spacing = 8
        let stack = NSStackView(views: [top, bottom])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        bottom.translatesAutoresizingMaskIntoConstraints = false

        background.addSubview(stack)
        NSLayoutConstraint.activate([
            background.widthAnchor.constraint(equalToConstant: Self.width),
            stack.topAnchor.constraint(equalTo: background.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -12),
            bottom.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        panel.contentView = background
    }

    var isShowing: Bool { panel.isVisible }

    /// Shows (or restarts) the reminder on the screen the pointer is on — the
    /// one the user is looking at; reading the pointer needs no permission.
    func show(seconds: Int, snoozeMinutes: Int) {
        snoozeButton.title = "Snooze \(snoozeMinutes) min"
        secondsLeft = seconds
        countdown.stringValue = Self.countdownText(seconds: secondsLeft)

        let screens = NSScreen.screens
        let index = Self.screenIndex(containing: NSEvent.mouseLocation, in: screens.map(\.frame))
        if let screen = index.map({ screens[$0] }) ?? NSScreen.main ?? screens.first {
            panel.contentView?.layoutSubtreeIfNeeded()
            let size = panel.contentView?.fittingSize ?? panel.frame.size
            panel.setFrame(NSRect(origin: Self.origin(for: size, in: screen.visibleFrame), size: size),
                           display: false)
        }
        panel.orderFrontRegardless()

        ticker?.invalidate()
        // .common: keep counting while one of our menus is open.
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.second() }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    func close() {
        ticker?.invalidate()
        ticker = nil
        panel.orderOut(nil)
    }

    private func second() {
        secondsLeft -= 1
        guard secondsLeft > 0 else {
            close()
            onFinish?()
            return
        }
        countdown.stringValue = Self.countdownText(seconds: secondsLeft)
    }

    @objc private func skip() {
        close()
        onSkip?()
    }

    @objc private func snooze() {
        close()
        onSnooze?()
    }

    // MARK: - Pure, unit-tested

    static func countdownText(seconds: Int) -> String {
        "Closes in \(max(0, seconds)) s"
    }

    /// Centred horizontally, just under the top of the usable area (below
    /// the menu bar and any notch).
    static func origin(for size: NSSize, in visible: NSRect) -> NSPoint {
        NSPoint(x: (visible.midX - size.width / 2).rounded(),
                y: (visible.maxY - size.height - topInset).rounded())
    }

    /// The screen under `point`, by index into `frames` (AppKit global
    /// coordinates), or nil if it is on none — then the caller falls back.
    static func screenIndex(containing point: NSPoint, in frames: [NSRect]) -> Int? {
        frames.firstIndex { NSMouseInRect(point, $0, false) }
    }

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

/// Never key, never main: keystrokes stay with the app the user is in.
private final class ReminderPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// A click on a window that isn't key is normally spent focusing it; this
/// panel is never key, so its buttons must act on that first click.
private final class FirstClickButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
