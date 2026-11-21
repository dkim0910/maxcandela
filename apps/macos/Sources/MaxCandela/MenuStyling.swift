import AppKit

/// The menu's visual vocabulary in one place: an SF Symbol in front of each
/// row, and titled sections. macOS 26 puts icons on its own menus, so a
/// text-only menu now reads as dated next to the system's.
extension NSMenuItem {
    /// Sets the row's leading icon. Template-rendered, so it follows the
    /// menu's light/dark/highlight colours by itself.
    @discardableResult
    func symbol(_ name: String) -> NSMenuItem {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        image?.isTemplate = true
        self.image = image
        return self
    }
}

extension NSMenu {
    /// A small grey heading that groups the rows under it.
    func addSection(_ title: String) {
        if !items.isEmpty { addItem(.separator()) }
        addItem(.sectionHeader(title: title))
    }
}
