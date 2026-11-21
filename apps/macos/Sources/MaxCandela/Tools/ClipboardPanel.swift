import AppKit

/// The searchable clipboard history window (Pro): type to filter, ↑/↓ to
/// move, Return to copy the selected entry back to the clipboard.
///
/// It copies; it does not paste into the front app. Pasting for the user
/// would need the Accessibility permission, and "⌘V after Return" is a small
/// price for not asking for it.
final class ClipboardPanel: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate, NSWindowDelegate {
    private let panel: NSPanel
    private let search = NSSearchField()
    private let table = NSTableView()
    private let pinButton = NSButton(title: "Pin", target: nil, action: nil)
    private var rows: [String] = []

    private let history: () -> ClipboardHistory
    private let onCopy: (String) -> Void
    private let onTogglePin: (String) -> Void
    private let onDelete: (String) -> Void

    init(history: @escaping () -> ClipboardHistory,
         onCopy: @escaping (String) -> Void,
         onTogglePin: @escaping (String) -> Void,
         onDelete: @escaping (String) -> Void) {
        self.history = history
        self.onCopy = onCopy
        self.onTogglePin = onTogglePin
        self.onDelete = onDelete
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
                        styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                        backing: .buffered, defer: false)
        super.init()

        panel.title = "Clipboard History"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.minSize = NSSize(width: 340, height: 260)

        search.placeholderString = "Search what you’ve copied"
        search.delegate = self
        search.translatesAutoresizingMaskIntoConstraints = false

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("text"))
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.headerView = nil
        table.rowHeight = 24
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(copySelected)
        table.style = .inset

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let copyButton = NSButton(title: "Copy", target: self, action: #selector(copySelected))
        copyButton.keyEquivalent = "\r"
        pinButton.target = self
        pinButton.action = #selector(togglePinSelected)
        let deleteButton = NSButton(title: "Delete", target: self, action: #selector(deleteSelected))
        let buttons = NSStackView(views: [pinButton, deleteButton, NSView(), copyButton])
        buttons.orientation = .horizontal
        buttons.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(search)
        content.addSubview(scroll)
        content.addSubview(buttons)
        NSLayoutConstraint.activate([
            search.topAnchor.constraint(equalTo: content.safeAreaLayoutGuide.topAnchor, constant: 10),
            search.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            search.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            scroll.topAnchor.constraint(equalTo: search.bottomAnchor, constant: 10),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            buttons.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 10),
            buttons.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
        ])
        panel.contentView = content
    }

    var isVisible: Bool { panel.isVisible }

    func show() {
        search.stringValue = ""
        reload()
        panel.center()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(search)
    }

    func close() { panel.orderOut(nil) }

    /// Call when the history changed underneath an open panel.
    func reload() {
        let selected = selectedText
        rows = history().ordered(matching: search.stringValue)
        table.reloadData()
        let index = selected.flatMap(rows.firstIndex(of:)) ?? 0
        if !rows.isEmpty {
            table.selectRowIndexes([index], byExtendingSelection: false)
            table.scrollRowToVisible(index)
        }
        updatePinButton()
    }

    private var selectedText: String? {
        rows.indices.contains(table.selectedRow) ? rows[table.selectedRow] : nil
    }

    private func updatePinButton() {
        pinButton.title = selectedText.map(history().isPinned) == true ? "Unpin" : "Pin"
    }

    // MARK: - Actions

    @objc private func copySelected() {
        guard let text = selectedText else { return }
        onCopy(text)
        close()
    }

    @objc private func togglePinSelected() {
        guard let text = selectedText else { return }
        onTogglePin(text)
        reload()
    }

    @objc private func deleteSelected() {
        guard let text = selectedText else { return }
        onDelete(text)
        reload()
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("cell")
        let field = tableView.makeView(withIdentifier: id, owner: nil) as? NSTextField
            ?? NSTextField(labelWithString: "")
        field.identifier = id
        field.lineBreakMode = .byTruncatingTail
        let text = rows[row]
        let title = ClipboardHistory.menuTitle(for: text, limit: 120)
        field.stringValue = history().isPinned(text) ? "📌 \(title)" : title
        field.toolTip = String(text.prefix(600))
        return field
    }

    func tableViewSelectionDidChange(_ notification: Notification) { updatePinButton() }

    // MARK: - Search field

    func controlTextDidChange(_ obj: Notification) { reload() }

    /// The search field keeps the keyboard focus, so the arrow keys and
    /// Escape have to be handed to the list from here.
    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.moveDown(_:)):
            move(by: 1)
        case #selector(NSResponder.moveUp(_:)):
            move(by: -1)
        case #selector(NSResponder.insertNewline(_:)):
            copySelected()
        case #selector(NSResponder.cancelOperation(_:)):
            close()
        default:
            return false
        }
        return true
    }

    private func move(by delta: Int) {
        guard !rows.isEmpty else { return }
        let index = max(0, min(rows.count - 1, table.selectedRow + delta))
        table.selectRowIndexes([index], byExtendingSelection: false)
        table.scrollRowToVisible(index)
    }
}
