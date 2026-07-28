import AppKit

/// The application's main menu.
///
/// A menu-bar-only (`.accessory`) app never *displays* a menu bar, so it is
/// tempting to skip this entirely — that is what we did, and it silently broke
/// ⌘C/⌘V everywhere. AppKit routes command-key presses through
/// `NSApp.mainMenu.performKeyEquivalent(_:)` *before* anything reaches the
/// focused control: with no Edit menu there is no item matching ⌘V, so
/// `paste(_:)` is never sent down the responder chain. Text fields we put on
/// screen (the offer-code redeem sheet, the paywall's terms text view) then
/// refuse to paste, with only the field's own right-click menu still working.
///
/// The items below carry no target, so each dispatches to the first responder.
/// Nothing here is ever visible: macOS keeps showing the frontmost regular
/// app's menu bar even while an accessory app is active.
enum AppMenu {
    static func install(on app: NSApplication) {
        let mainMenu = NSMenu()

        // The first submenu is the app menu by convention; keep that slot so
        // the Edit menu isn't promoted into it.
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit MaxCandela",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem()
        editItem.submenu = editMenu()
        mainMenu.addItem(editItem)

        app.mainMenu = mainMenu
    }

    private static func editMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")

        // undo:/redo: have no concrete declaration to take a #selector of —
        // they are pure responder-chain messages handled by NSUndoManager.
        menu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = menu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]

        menu.addItem(.separator())

        menu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        let matchStyle = menu.addItem(withTitle: "Paste and Match Style",
                                      action: #selector(NSTextView.pasteAsPlainText(_:)),
                                      keyEquivalent: "v")
        matchStyle.keyEquivalentModifierMask = [.command, .option, .shift]
        menu.addItem(withTitle: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")

        menu.addItem(.separator())

        menu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        return menu
    }
}
