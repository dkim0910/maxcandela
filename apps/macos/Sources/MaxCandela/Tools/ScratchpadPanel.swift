import AppKit

/// The scratchpad window: one plain-text view with Copy All and Clear.
///
/// Unlike the break reminder this window *is* meant to take the keyboard —
/// the user opened it to type — so it activates the app and becomes key.
/// ⌘C/⌘V/⌘A/⌘Z reach the text view through `AppMenu`'s Edit menu, which
/// is why they work at all in an accessory app; ⌘W and Escape close it
/// (there is no File menu to carry ⌘W).
final class ScratchpadPanel: NSObject, NSTextViewDelegate, NSWindowDelegate {
    private let panel: ScratchpadWindow
    private let textView: NSTextView
    private let clearButton = NSButton(title: "Clear", target: nil, action: nil)
    private let copyButton = NSButton(title: "Copy All", target: nil, action: nil)
    /// The window's own, so an undone Clear survives closing and reopening.
    private let undo = UndoManager()
    /// Set while Clear is changing the text, so the change it causes doesn't
    /// immediately turn "Undo Clear" back into "Clear".
    private var isClearing = false
    private var copiedReset: DispatchWorkItem?
    /// The app that was in front when the scratchpad opened. Closing hands
    /// the keyboard back to it — an accessory app with no window left would
    /// otherwise keep focus, and the next keystroke would just beep. Strong:
    /// `frontmostApplication` returns an instance nothing else keeps.
    private var returnFocusTo: NSRunningApplication?

    private let onChange: (String) -> Void
    private let onCopyAll: (String) -> Void
    private let onClose: () -> Void

    init(text: String,
         onChange: @escaping (String) -> Void,
         onCopyAll: @escaping (String) -> Void,
         onClose: @escaping () -> Void) {
        self.onChange = onChange
        self.onCopyAll = onCopyAll
        self.onClose = onClose
        panel = ScratchpadWindow(contentRect: NSRect(x: 0, y: 0, width: 380, height: 320),
                                 styleMask: [.titled, .closable, .resizable],
                                 backing: .buffered, defer: true)
        let scroll = NSTextView.scrollableTextView()
        textView = scroll.documentView as? NSTextView ?? NSTextView()
        super.init()

        panel.title = "Scratchpad"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.minSize = NSSize(width: 260, height: 180)
        // Follows the user to whichever Space (or full-screen app) they
        // summon it from, instead of yanking them back to where it was.
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        // Remembers where the user put it and how big they made it.
        panel.setFrameAutosaveName("MaxCandelaScratchpad")
        if !panel.setFrameUsingName("MaxCandelaScratchpad") { panel.center() }
        panel.onCloseKey = { [weak self] in self?.close() }

        Self.configure(textView)
        textView.string = text
        textView.delegate = self
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false

        clearButton.target = self
        clearButton.action = #selector(clearOrUndo)
        copyButton.target = self
        copyButton.action = #selector(copyAll)
        let buttons = NSStackView(views: [clearButton, NSView(), copyButton])
        buttons.orientation = .horizontal
        buttons.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(scroll)
        content.addSubview(buttons)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: content.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            buttons.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 8),
            buttons.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -10),
        ])
        panel.contentView = content
        updateButtons()
    }

    var isKey: Bool { panel.isVisible && panel.isKeyWindow }

    func show() {
        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            returnFocusTo = front
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(textView)
    }

    /// ⌘W, Escape, the shortcut again. `close()` (not `orderOut`) so the
    /// delegate's windowWillClose runs — one path for the save and the
    /// hand-back, whichever way the window went.
    func close() {
        guard panel.isVisible else { return }
        panel.close()
    }

    /// Plain text only, and none of the "smart" substitutions that would
    /// quietly change a pasted command or snippet.
    static func configure(_ textView: NSTextView) {
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 6, height: 8)
    }

    /// Empty the text view as one undoable step. Going through
    /// shouldChangeText/didChangeText is what registers the undo and sends
    /// the change notification (and so the autosave) — setting `string`
    /// directly does neither. Returns false if there was nothing to clear.
    @discardableResult
    static func clearUndoably(_ textView: NSTextView) -> Bool {
        let all = NSRange(location: 0, length: (textView.string as NSString).length)
        guard all.length > 0, textView.shouldChangeText(in: all, replacementString: "") else { return false }
        textView.replaceCharacters(in: all, with: "")
        textView.didChangeText()
        textView.undoManager?.setActionName("Clear")
        return true
    }

    // MARK: - Actions

    @objc private func clearOrUndo() {
        if clearButton.title == "Undo Clear" {
            if undo.canUndo { undo.undo() }
            return
        }
        isClearing = true
        let cleared = Self.clearUndoably(textView)
        isClearing = false
        if cleared { clearButton.title = "Undo Clear" }
        updateButtons()
    }

    @objc private func copyAll() {
        onCopyAll(textView.string)
        guard !textView.string.isEmpty else { return }
        copyButton.title = "Copied"
        copiedReset?.cancel()
        let reset = DispatchWorkItem { [weak self] in self?.copyButton.title = "Copy All" }
        copiedReset = reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: reset)
    }

    private func updateButtons() {
        let empty = textView.string.isEmpty
        clearButton.isEnabled = !empty || clearButton.title == "Undo Clear"
        copyButton.isEnabled = !empty
    }

    // MARK: - Delegates

    func textDidChange(_ notification: Notification) {
        // Any edit other than Clear itself (typing, or the undo of the
        // Clear) retires the "Undo Clear" offer.
        if !isClearing { clearButton.title = "Clear" }
        updateButtons()
        onChange(textView.string)
    }

    // Both, so the text view registers into the same manager that the Edit
    // menu's Undo (sent to the window via the responder chain) undoes from.
    func undoManager(for view: NSTextView) -> UndoManager? { undo }
    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? { undo }

    func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        // Escape. NSTextView would otherwise use it for word completion.
        guard selector == #selector(NSResponder.cancelOperation(_:)) else { return false }
        close()
        return true
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
        // Only if it was ours to give back: the user closed the scratchpad
        // while typing in it, not while working in some other app.
        if panel.isKeyWindow, let app = returnFocusTo, !app.isTerminated {
            app.activate()
        }
        returnFocusTo = nil
    }
}

/// Handles ⌘W itself: an accessory app has no File ▸ Close item to carry it.
private final class ScratchpadWindow: NSPanel {
    var onCloseKey: (() -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == .command, event.charactersIgnoringModifiers == "w" {
            onCloseKey?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
