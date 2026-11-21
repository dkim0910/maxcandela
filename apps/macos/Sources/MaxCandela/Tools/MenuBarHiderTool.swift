import AppKit

/// Hide Menu Bar Icons (Pro): collapse the icons you rarely need behind a
/// chevron.
///
/// The technique is the one the open-source Hidden Bar uses, and needs no
/// permission: two extra status items, a **chevron** and, to its left, a
/// **divider**. Anything the user ⌘-drags to the left of the divider is
/// "hidden"; collapsing sets the divider's length so large that everything to
/// its left is pushed off the screen. Expanding puts the length back.
///
/// ⚠️ Built on macOS 26 without being able to see the menu bar. Two things to
/// confirm by eye: that a very long status item still pushes its neighbours
/// off-screen on this macOS, and where the two items land relative to ☀️
/// (status items are placed right-to-left in creation order, then remembered
/// under their autosave names).
final class MenuBarHiderTool: MenuTool {
    let menuItem = NSMenuItem(title: "Hide Menu Bar Icons", action: nil, keyEquivalent: "")
    var onStatusChange: (() -> Void)?
    var isPro: Bool { true }

    private var chevron: NSStatusItem?
    private var divider: NSStatusItem?
    private(set) var isCollapsed = false

    private static let enabledKey = "com.maxcandela.hider.enabled"
    private static let collapsedKey = "com.maxcandela.hider.collapsed"
    /// Wider than any display, so everything left of the divider leaves it.
    static let collapsedLength: CGFloat = 10_000
    static let dividerLength: CGFloat = 12

    private let enableItem = NSMenuItem(title: "Show the Divider and Chevron", action: nil, keyEquivalent: "")
    private let collapseItem = NSMenuItem(title: "Hide the Icons Left of the Divider", action: nil, keyEquivalent: "")

    private var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    init() {
        let submenu = NSMenu()
        enableItem.target = self
        enableItem.action = #selector(toggleEnabled)
        submenu.addItem(enableItem)
        collapseItem.target = self
        collapseItem.action = #selector(toggleCollapsed)
        submenu.addItem(collapseItem)
        submenu.addItem(.separator())
        let help = NSMenuItem(title: "Hold ⌘ and drag icons to the left of the │ divider", action: nil, keyEquivalent: "")
        help.isEnabled = false
        submenu.addItem(help)
        menuItem.submenu = submenu
        menuItem.symbol("menubar.rectangle")

        ProGate.shared.observe { [weak self] allowed in
            // Pro lapsed: give the menu bar back exactly as macOS lays it out.
            if allowed { self?.restore() } else { self?.remove() }
        }
        if ProGate.shared.isAllowed { restore() }
        updateMenu()
    }

    func menuWillOpen() { updateMenu() }
    func shutdown() { remove() }

    /// Pure, unit-tested.
    static func length(collapsed: Bool) -> CGFloat {
        collapsed ? collapsedLength : dividerLength
    }

    private func restore() {
        guard enabled, chevron == nil else { return }
        install()
        setCollapsed(UserDefaults.standard.bool(forKey: Self.collapsedKey))
    }

    private func install() {
        // Chevron first, so it sits to the right of the divider.
        let chevron = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        chevron.autosaveName = "MaxCandelaHiderChevron"
        chevron.button?.target = self
        chevron.button?.action = #selector(toggleCollapsed)
        chevron.button?.toolTip = "Show or hide menu bar icons"
        self.chevron = chevron

        let divider = NSStatusBar.system.statusItem(withLength: Self.dividerLength)
        divider.autosaveName = "MaxCandelaHiderDivider"
        divider.button?.title = "│"
        divider.button?.appearsDisabled = true
        divider.button?.toolTip = "Icons to the left of this line can be hidden"
        self.divider = divider
    }

    private func remove() {
        if let chevron { NSStatusBar.system.removeStatusItem(chevron) }
        if let divider { NSStatusBar.system.removeStatusItem(divider) }
        chevron = nil
        divider = nil
        isCollapsed = false
        updateMenu()
    }

    private func setCollapsed(_ collapsed: Bool) {
        guard let divider, let chevron else { return }
        isCollapsed = collapsed
        UserDefaults.standard.set(collapsed, forKey: Self.collapsedKey)
        divider.length = Self.length(collapsed: collapsed)
        let symbol = collapsed ? "chevron.left" : "chevron.right"
        chevron.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Show or hide menu bar icons")
        chevron.button?.image?.isTemplate = true
        updateMenu()
    }

    private func updateMenu() {
        enableItem.state = chevron != nil ? .on : .off
        collapseItem.state = isCollapsed ? .on : .off
        collapseItem.isHidden = chevron == nil
    }

    @objc private func toggleEnabled() {
        enabled.toggle()
        if enabled { restore() } else { remove() }
        updateMenu()
    }

    @objc private func toggleCollapsed() {
        setCollapsed(!isCollapsed)
    }
}
