import AppKit

/// When the scratchpad's text should be written to disk. Pure, unit-tested.
///
/// A save waits for a pause in typing (`quietPeriod`), so a burst of
/// keystrokes is one write, not one per key — but never longer than
/// `maximumDelay` after the first unsaved edit, so someone typing without
/// pause for minutes still has their text on disk every few seconds.
struct ScratchpadAutosave: Equatable {
    static let quietPeriod: TimeInterval = 1
    static let maximumDelay: TimeInterval = 10

    private(set) var firstUnsavedEdit: TimeInterval?
    private(set) var lastEdit: TimeInterval?

    var isDirty: Bool { firstUnsavedEdit != nil }

    mutating func edited(at now: TimeInterval) {
        if firstUnsavedEdit == nil { firstUnsavedEdit = now }
        lastEdit = now
    }

    /// When the pending save is due, or nil when there is nothing to save.
    var deadline: TimeInterval? {
        guard let firstUnsavedEdit, let lastEdit else { return nil }
        return min(lastEdit + Self.quietPeriod, firstUnsavedEdit + Self.maximumDelay)
    }

    func shouldSave(at now: TimeInterval) -> Bool {
        deadline.map { now >= $0 } ?? false
    }

    mutating func saved() {
        firstUnsavedEdit = nil
        lastEdit = nil
    }
}

/// Scratchpad: a small floating plain-text notes window, opened from the
/// menu or (opt-in) ⌃⌥⌘N from any app. The text autosaves a moment after
/// typing stops, to `Application Support/MaxCandela/scratchpad.txt` — inside
/// the app's sandbox container, so no file permission is involved — and is
/// back after a relaunch. Copy All and Clear live in the window; Clear is
/// undoable (⌘Z, or the button that briefly becomes "Undo Clear").
///
/// The shortcut is off by default for the same reason as the boost's: a
/// global chord that is on out of the box can shadow the same chord in
/// whatever app the user is in.
final class ScratchpadTool: MenuTool {
    let menuItem = NSMenuItem(title: "Scratchpad", action: nil, keyEquivalent: "")
    var onStatusChange: (() -> Void)?

    static let shortcut = Shortcut(keyCode: 45 /* kVK_ANSI_N */,
                                   carbonModifiers: Shortcut.standard.carbonModifiers,
                                   display: "⌃⌥⌘N")
    private static let shortcutKey = "com.maxcandela.scratchpad.shortcut"

    private let submenu = NSMenu()
    private let hotKey = GlobalHotKey()
    /// The source of truth; the window edits it through `textChanged`.
    private var text: String
    private var autosave = ScratchpadAutosave()
    private var saveTimer: Timer?
    /// Built on first open — most launches never show it.
    private var panel: ScratchpadPanel?

    private var shortcutEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.shortcutKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.shortcutKey) }
    }

    private static var now: TimeInterval { Date().timeIntervalSinceReferenceDate }

    init() {
        text = Self.load()
        menuItem.submenu = submenu
        menuItem.symbol("note.text")
        hotKey.onPress = { [weak self] in self?.toggleFromShortcut() }
        if shortcutEnabled, !hotKey.register(Self.shortcut) {
            // Another app owns the chord. Show the switch as off rather than
            // claim a shortcut that does nothing.
            shortcutEnabled = false
        }
        rebuild()
    }

    func menuWillOpen() { rebuild() }

    func shutdown() {
        hotKey.unregister()
        saveNow()
    }

    // MARK: - Menu

    private func rebuild() {
        submenu.removeAllItems()
        let suffix = hotKey.isRegistered ? "   \(Self.shortcut.display)" : ""
        let open = NSMenuItem(title: "Open Scratchpad…\(suffix)", action: #selector(openPanel), keyEquivalent: "")
        open.target = self
        submenu.addItem(open.symbol("square.and.pencil"))

        let copy = NSMenuItem(title: "Copy All", action: #selector(copyAll), keyEquivalent: "")
        copy.target = self
        copy.isEnabled = !text.isEmpty
        submenu.addItem(copy.symbol("doc.on.doc"))

        submenu.addItem(.separator())
        let shortcut = NSMenuItem(title: "Open with \(Self.shortcut.display)", action: #selector(toggleShortcut), keyEquivalent: "")
        shortcut.target = self
        shortcut.state = hotKey.isRegistered ? .on : .off
        shortcut.toolTip = "Opens and closes the scratchpad from any app. Off by default so it never takes over the same keys in another app."
        submenu.addItem(shortcut.symbol("keyboard"))
    }

    @objc private func openPanel() { makePanel().show() }

    private func toggleFromShortcut() {
        if let panel, panel.isKey {
            panel.close()
        } else {
            makePanel().show()
        }
    }

    @objc private func copyAll() { Self.copy(text) }

    @objc private func toggleShortcut() {
        if hotKey.isRegistered {
            hotKey.unregister()
            shortcutEnabled = false
        } else if hotKey.register(Self.shortcut) {
            shortcutEnabled = true
        } else {
            // Taken by another app; the item stays unticked.
            NSSound.beep()
        }
        rebuild()
    }

    private static func copy(_ text: String) {
        guard !text.isEmpty else { return NSSound.beep() }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func makePanel() -> ScratchpadPanel {
        if let panel { return panel }
        let built = ScratchpadPanel(
            text: text,
            onChange: { [weak self] in self?.textChanged($0) },
            onCopyAll: { Self.copy($0) },
            onClose: { [weak self] in self?.saveNow() })
        panel = built
        return built
    }

    // MARK: - Saving

    private func textChanged(_ newText: String) {
        text = newText
        autosave.edited(at: Self.now)
        scheduleSave()
    }

    private func scheduleSave() {
        saveTimer?.invalidate()
        guard let deadline = autosave.deadline else { return }
        let timer = Timer(fire: Date(timeIntervalSinceReferenceDate: deadline), interval: 0, repeats: false) { [weak self] _ in
            self?.saveIfDue()
        }
        // .common: typing in the panel while one of our menus is open is
        // unlikely, but a save should never wait on menu tracking.
        RunLoop.main.add(timer, forMode: .common)
        saveTimer = timer
    }

    private func saveIfDue() {
        if autosave.shouldSave(at: Self.now) {
            saveNow()
        } else {
            scheduleSave()
        }
    }

    /// Write now if anything is unsaved: on close, at quit, and when due.
    private func saveNow() {
        saveTimer?.invalidate()
        saveTimer = nil
        guard autosave.isDirty else { return }
        if Self.save(text) { autosave.saved() }
    }

    static var storeURL: URL? {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        return support.appendingPathComponent("MaxCandela", isDirectory: true)
            .appendingPathComponent("scratchpad.txt")
    }

    private static func load() -> String {
        guard let url = storeURL else { return "" }
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    /// Atomic, so a crash mid-write leaves the previous text, not half of it.
    @discardableResult
    private static func save(_ text: String) -> Bool {
        guard let url = storeURL else { return false }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            NSLog("MaxCandela: could not save the scratchpad (%@)", error.localizedDescription)
            return false
        }
    }
}
