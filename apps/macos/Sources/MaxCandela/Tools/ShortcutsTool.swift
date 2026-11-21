import AppKit

/// Shortcuts (Pro): run your own Apple Shortcuts from the menu.
///
/// This is how the toolbox reaches things an App Store app may not do
/// itself — toggle Dark Mode, set a Focus, control HomeKit: the user builds
/// (or already has) a Shortcut for it and adds its name here. Running goes
/// through the documented `shortcuts://run-shortcut` URL, which the Shortcuts
/// app handles; we never see what the shortcut does.
///
/// Names are typed, not picked from a list: there is no public API to
/// enumerate a user's shortcuts from a sandboxed app.
final class ShortcutsTool: MenuTool {
    let menuItem = NSMenuItem(title: "Shortcuts", action: nil, keyEquivalent: "")
    var onStatusChange: (() -> Void)?
    var isPro: Bool { true }

    private let submenu = NSMenu()
    private static let namesKey = "com.maxcandela.shortcuts.names"

    private var names: [String] {
        get { UserDefaults.standard.stringArray(forKey: Self.namesKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: Self.namesKey) }
    }

    init() {
        menuItem.submenu = submenu
        menuItem.symbol("square.stack.3d.up")
        rebuild()
    }

    func menuWillOpen() { rebuild() }

    /// Pure, unit-tested. nil for a blank name.
    static func runURL(name: String) -> URL? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "shortcuts"
        components.host = "run-shortcut"
        components.queryItems = [URLQueryItem(name: "name", value: trimmed)]
        return components.url
    }

    /// Pure, unit-tested. Trims, drops blanks and case-insensitive repeats.
    static func adding(_ name: String, to names: [String]) -> [String] {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !names.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame })
        else { return names }
        return names + [trimmed]
    }

    private func rebuild() {
        submenu.removeAllItems()
        let current = names
        for name in current {
            let item = NSMenuItem(title: name, action: #selector(run(_:)), keyEquivalent: "")
            item.target = self
            submenu.addItem(item.symbol("play"))
        }
        if current.isEmpty {
            let empty = NSMenuItem(title: "No shortcuts added yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
        }
        submenu.addItem(.separator())
        let add = NSMenuItem(title: "Add a Shortcut…", action: #selector(add), keyEquivalent: "")
        add.target = self
        submenu.addItem(add.symbol("plus"))
        if !current.isEmpty {
            let removeItem = NSMenuItem(title: "Remove", action: nil, keyEquivalent: "")
            let removeMenu = NSMenu()
            for name in current {
                let item = NSMenuItem(title: name, action: #selector(remove(_:)), keyEquivalent: "")
                item.target = self
                removeMenu.addItem(item)
            }
            removeItem.submenu = removeMenu
            submenu.addItem(removeItem.symbol("minus"))
        }
        let open = NSMenuItem(title: "Open the Shortcuts App", action: #selector(openApp), keyEquivalent: "")
        open.target = self
        submenu.addItem(open.symbol("arrow.up.forward.app"))
    }

    @objc private func run(_ sender: NSMenuItem) {
        guard let url = Self.runURL(name: sender.title) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func add() {
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.placeholderString = "Exactly as it is named in Shortcuts"
        let alert = NSAlert()
        alert.messageText = "Add a Shortcut"
        alert.informativeText = "Type the name of a shortcut from the Shortcuts app. It will appear in this menu, ready to run."
        alert.accessoryView = field
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        names = Self.adding(field.stringValue, to: names)
    }

    @objc private func remove(_ sender: NSMenuItem) {
        names.removeAll { $0 == sender.title }
    }

    @objc private func openApp() {
        if let url = URL(string: "shortcuts://") { NSWorkspace.shared.open(url) }
    }
}
