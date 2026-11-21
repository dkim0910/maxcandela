import AppKit

/// Clipboard: text tools that rewrite what is on the clipboard, and an
/// opt-in history of the last few things copied.
///
/// Privacy decisions, all deliberate:
///  - **History is off until the user turns it on.** macOS has been moving
///    toward warning when an app reads the pasteboard without the user asking
///    (`NSPasteboard.accessBehavior`, macOS 15.4+); a tool that silently reads
///    everything copied should be something the user chose.
///  - **Kept in memory only by default.** Never sent anywhere, gone at quit.
///    Pro's "Remember After Quit" is a second, separate opt-in that writes
///    the history to a file in the app's own sandbox container — and turning
///    it off deletes that file.
///  - **Passwords are skipped.** Password managers mark what they copy with
///    the nspasteboard.org `ConcealedType` / `TransientType`; anything
///    carrying either is not recorded.
/// The text tools read the clipboard only at the moment the user clicks one.
///
/// Free: the last 15 entries, in this menu. Pro (`ProGate`): 200 entries,
/// pins, the searchable panel on ⌃⌥⌘V, and Remember After Quit.
final class ClipboardTool: MenuTool {
    let menuItem = NSMenuItem(title: "Clipboard", action: nil, keyEquivalent: "")
    var onStatusChange: (() -> Void)?

    private let submenu = NSMenu()
    private let pasteboard = NSPasteboard.general
    private var history = ClipboardHistory()
    private var lastChangeCount: Int
    private var pollTimer: Timer?
    private let hotKey = GlobalHotKey()
    /// Built on first use — most launches never open it. `openPanel` is the
    /// "only if it already exists" view of it, for closing and refreshing.
    private var openPanel: ClipboardPanel? { panelIfBuilt }
    private var panelIfBuilt: ClipboardPanel?
    private func makePanel() -> ClipboardPanel {
        if let panelIfBuilt { return panelIfBuilt }
        let built = buildPanel()
        panelIfBuilt = built
        return built
    }
    private func buildPanel() -> ClipboardPanel { ClipboardPanel(
        history: { [weak self] in self?.history ?? ClipboardHistory() },
        onCopy: { [weak self] in self?.write($0) },
        onTogglePin: { [weak self] in self?.mutate { $0.togglePin($1) }($0) },
        onDelete: { [weak self] in self?.mutate { $0.remove($1) }($0) }) }

    static let panelShortcut = Shortcut(keyCode: 9 /* kVK_ANSI_V */,
                                        carbonModifiers: Shortcut.standard.carbonModifiers,
                                        display: "⌃⌥⌘V")

    private static let enabledKey = "com.maxcandela.clipboard.historyEnabled"
    private static let rememberKey = "com.maxcandela.clipboard.remember"
    private static let skippedTypes = [
        NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"),
        NSPasteboard.PasteboardType("org.nspasteboard.TransientType"),
    ]

    private var historyEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    private var remember: Bool {
        get { UserDefaults.standard.bool(forKey: Self.rememberKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.rememberKey) }
    }

    private var capacity: Int {
        ProGate.shared.isAllowed ? ClipboardHistory.proCapacity : ClipboardHistory.freeCapacity
    }

    init() {
        lastChangeCount = pasteboard.changeCount
        menuItem.submenu = submenu
        menuItem.symbol("doc.on.clipboard")
        hotKey.onPress = { [weak self] in self?.showPanel() }
        if historyEnabled { startPolling() }
        ProGate.shared.observe { [weak self] _ in self?.proChanged() }
        proChanged()
        rebuild()
    }

    func menuWillOpen() { rebuild() }
    func shutdown() { pollTimer?.invalidate() }

    // MARK: - Pro

    /// Pro arriving loads a remembered history and arms the shortcut; Pro
    /// lapsing drops back to the free limits and lets the shortcut go. The
    /// saved file is left alone — it is the user's, and Pro may come back.
    private func proChanged() {
        if ProGate.shared.isAllowed {
            if historyEnabled, remember, history.entries.isEmpty, let saved = Self.load() {
                history = saved
            }
            if historyEnabled { hotKey.register(Self.panelShortcut) }
        } else {
            hotKey.unregister()
            openPanel?.close()
            var trimmed = history
            trimmed.trim(to: ClipboardHistory.freeCapacity)
            history = trimmed
        }
    }

    /// Apply a change to the history, then persist and refresh what shows it.
    private func mutate(_ change: @escaping (inout ClipboardHistory, String) -> Void) -> (String) -> Void {
        { [weak self] text in
            guard let self else { return }
            change(&self.history, text)
            self.historyChanged()
        }
    }

    private func historyChanged() {
        if remember, ProGate.shared.isAllowed { Self.save(history) }
        if let openPanel, openPanel.isVisible { openPanel.reload() }
    }

    private static var storeURL: URL? {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        return support.appendingPathComponent("MaxCandela", isDirectory: true)
            .appendingPathComponent("clipboard-history.json")
    }

    private static func load() -> ClipboardHistory? {
        guard let url = storeURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ClipboardHistory.self, from: data)
    }

    private static func save(_ history: ClipboardHistory) {
        guard let url = storeURL, let data = try? JSONEncoder().encode(history) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // .completeFileProtection is iOS-only; the sandbox container is what
        // keeps other apps out of this file on the Mac.
        try? data.write(to: url, options: .atomic)
    }

    @objc private func showPanel() {
        ProGate.shared.run { makePanel().show() }
    }

    @objc private func toggleRemember() {
        ProGate.shared.run {
            remember.toggle()
            if remember {
                Self.save(history)
            } else if let url = Self.storeURL {
                try? FileManager.default.removeItem(at: url)
            }
            rebuild()
        }
    }

    // MARK: - History

    private func startPolling() {
        pollTimer?.invalidate()
        lastChangeCount = pasteboard.changeCount
        // There is no pasteboard-changed notification on macOS; polling the
        // change count is the documented way to notice a copy.
        let timer = Timer(timeInterval: 0.75, repeats: true) { [weak self] _ in
            self?.poll()
        }
        timer.tolerance = 0.25
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func poll() {
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        let types = pasteboard.types ?? []
        guard !Self.skippedTypes.contains(where: types.contains),
              let text = pasteboard.string(forType: .string) else { return }
        history.add(text, capacity: capacity)
        historyChanged()
    }

    @objc private func toggleHistory() {
        historyEnabled.toggle()
        if historyEnabled {
            startPolling()
            proChanged()
        } else {
            pollTimer?.invalidate()
            pollTimer = nil
            hotKey.unregister()
            openPanel?.close()
            history.clear()
            // Switching history off is a request to forget, on disk too.
            if let url = Self.storeURL { try? FileManager.default.removeItem(at: url) }
        }
        rebuild()
    }

    @objc private func copyEntry(_ sender: NSMenuItem) {
        guard let text = sender.representedObject as? String else { return }
        write(text)
    }

    @objc private func clearHistory() {
        history.clear()
        historyChanged()
        rebuild()
    }

    // MARK: - Text tools

    @objc private func applyTransform(_ sender: NSMenuItem) {
        let transform = TextTransform.allCases[sender.tag]
        guard let text = pasteboard.string(forType: .string),
              let result = transform.apply(to: text) else {
            // Nothing usable on the clipboard for this tool (not JSON, not
            // Base64, not text). Leave it untouched rather than blank it.
            NSSound.beep()
            return
        }
        write(result)
    }

    private func write(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    // MARK: - Menu

    private func rebuild() {
        submenu.removeAllItems()

        let toggle = NSMenuItem(title: "Keep Clipboard History", action: #selector(toggleHistory), keyEquivalent: "")
        toggle.target = self
        toggle.state = historyEnabled ? .on : .off
        toggle.toolTip = "Remembers the last \(ClipboardHistory.freeCapacity) pieces of text you copy (\(ClipboardHistory.proCapacity) with Pro). Kept in memory and cleared when you quit unless you turn on Remember After Quit; passwords copied from password managers are skipped."
        submenu.addItem(toggle)

        if historyEnabled {
            let pro = ProGate.shared.isAllowed ? "" : " — Pro"
            let searchItem = NSMenuItem(title: "Search History…   \(Self.panelShortcut.display)\(pro)",
                                        action: #selector(showPanel), keyEquivalent: "")
            searchItem.target = self
            submenu.addItem(searchItem.symbol("magnifyingglass"))
            let rememberItem = NSMenuItem(title: "Remember After Quit\(pro)", action: #selector(toggleRemember), keyEquivalent: "")
            rememberItem.target = self
            rememberItem.state = remember && ProGate.shared.isAllowed ? .on : .off
            submenu.addItem(rememberItem.symbol("externaldrive"))
            submenu.addItem(.separator())

            if history.entries.isEmpty {
                let empty = NSMenuItem(title: "Nothing copied yet", action: nil, keyEquivalent: "")
                empty.isEnabled = false
                submenu.addItem(empty)
            }
            // The menu stays a short list whatever the tier; the panel is
            // where 200 entries are usable.
            for entry in history.ordered().prefix(ClipboardHistory.freeCapacity) {
                let prefix = history.isPinned(entry) ? "📌 " : ""
                let item = NSMenuItem(title: prefix + ClipboardHistory.menuTitle(for: entry),
                                      action: #selector(copyEntry(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = entry
                item.indentationLevel = 1
                submenu.addItem(item)
            }
            if !history.entries.isEmpty {
                let clear = NSMenuItem(title: "Clear History", action: #selector(clearHistory), keyEquivalent: "")
                clear.target = self
                submenu.addItem(clear)
            }
        }

        submenu.addItem(.separator())
        let header = NSMenuItem(title: "Change Clipboard Text To", action: nil, keyEquivalent: "")
        header.isEnabled = false
        submenu.addItem(header)
        for (index, transform) in TextTransform.allCases.enumerated() {
            if transform.startsGroup { submenu.addItem(.separator()) }
            let item = NSMenuItem(title: transform.title, action: #selector(applyTransform(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            submenu.addItem(item)
        }
    }
}
