import AppKit

/// The "press the keys you want" box in the Change Shortcut dialog.
///
/// Captures in `performKeyEquivalent` as well as `keyDown`: anything with ⌘
/// is offered to key equivalents first — and `AppMenu`'s Edit menu would
/// happily take ⌘C/⌘V before `keyDown` ever saw them.
final class ShortcutRecorderView: NSView {
    private(set) var shortcut: Shortcut
    private let label = NSTextField(labelWithString: "")

    init(shortcut: Shortcut) {
        self.shortcut = shortcut
        super.init(frame: NSRect(x: 0, y: 0, width: 220, height: 34))
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        label.frame = NSRect(x: 0, y: 7, width: bounds.width, height: 20)
        label.stringValue = shortcut.display
        addSubview(label)
        setAccessibilityLabel("Shortcut")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override var acceptsFirstResponder: Bool { true }

    // Layer colours are CGColors and don't follow light/dark by themselves.
    override func updateLayer() {
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.isKeyWindow == true, capture(event) else {
            return super.performKeyEquivalent(with: event)
        }
        return true
    }

    override func keyDown(with event: NSEvent) {
        // Not a shortcut (bare Return/Escape, plain letters): let the dialog's
        // own buttons have it.
        if !capture(event) { super.keyDown(with: event) }
    }

    private func capture(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown, let recorded = Shortcut(event: event) else { return false }
        shortcut = recorded
        label.stringValue = recorded.display
        return true
    }
}
