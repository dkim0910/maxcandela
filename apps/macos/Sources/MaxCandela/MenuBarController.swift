import AppKit
import StoreKit

/// The menu-bar surface on the ☀️ status icon:
///
/// - single click  → toggle the boost instantly (license permitting)
/// - double click  → open the menu (undoing the first click's toggle)
/// - right-click   → open the menu
/// - single click on a display with no EDR headroom → open the menu, since a
///   toggle there would do nothing
///
/// App Review (2026-07-20, Guidelines 4 + 3.1.1) rejected an earlier build
/// where the menu was reachable *only* by right-click: the reviewer's MacBook
/// Air has no EDR headroom, so clicking produced a dead-end alert and they
/// never found Quit or Restore Purchases. The no-headroom rule above keeps
/// that path open — on the Macs where the boost can't work, one click still
/// reaches the whole menu.
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let brightness: BrightnessController
    private let store = StoreManager.shared
    private let boostItem: NSMenuItem
    private let headroomItem: NSMenuItem
    private let licenseItem: NSMenuItem
    private let lifetimeItem: NSMenuItem
    private let monthlyItem: NSMenuItem
    private let restoreItem: NSMenuItem
    private let redeemItem: NSMenuItem
    private let menu: NSMenu

    /// Extra Dim + Warmth sliders (custom-view menu items).
    private var dimSlider: SliderMenuItemView!
    private var warmthSlider: SliderMenuItemView!
    private let batteryItem = NSMenuItem(title: "Pause Boost on Battery", action: nil, keyEquivalent: "")
    private let hotKeyItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    /// Rebuilt on every menu open — the running apps and the hours' check
    /// marks are only known then.
    private let scheduleMenu = NSMenu()
    private let appsMenu = NSMenu()
    private let loginItem = NSMenuItem(title: "Launch at Login", action: nil, keyEquivalent: "")
    private let hotKey = GlobalHotKey()

    /// The toolbox: everything in the menu that is not the display. Order
    /// here is the order in the menu. See `MenuTool`.
    private let tools: [MenuTool] = [
        KeepAwakeTool(), TimerTool(), FocusTool(), BreaksTool(),
        ClipboardTool(), ScratchpadTool(), ColorPickerTool(),
        GeneratorTool(), WorldClockTool(), MonthCalendarTool(), AudioTool(), SystemTool(), DesktopTool(),
        // Pro (`isPro`): listed under their own heading by buildMenu().
        MenuBarHiderTool(), WindowSnapTool(), ScreenshotTool(),
        ScreenTextTool(), ScreenTextTool(reading: .codes), ShortcutsTool(), CalendarTool(),
        BluetoothTool(), FileShelfTool(), WindowDimmerTool(),
        AppVolumeTool(),
    ].filter { $0.isSupported }
    /// The "— Pro" row shown in place of each Pro tool while Pro is not
    /// available; clicking it opens the paywall.
    private var lockedItems: [(tool: MenuTool, locked: NSMenuItem)] = []
    /// The tools section is the one part of the menu the user can re-lay-out
    /// (Options ▸ Menu Layout), so it is tracked separately: where it starts,
    /// what was inserted, and the group submenus holding tool rows.
    private var toolSectionStart = 0
    private var toolSectionItems: [NSMenuItem] = []
    private var groupSubmenus: [NSMenu] = []
    private var layoutItems: [(layout: MenuLayout, item: NSMenuItem)] = []
    private let clickItem = NSMenuItem(title: "Clicking the Icon Toggles the Boost", action: nil, keyEquivalent: "")

    /// One row per display, present only while more than one can boost.
    private var perDisplayItems: [NSMenuItem] = []
    /// The display set those rows were built for, so a refresh on an *open*
    /// menu can retitle in place instead of rebuilding.
    private var perDisplayNames: [String] = []

    /// Refreshes the figures while the menu is on screen. Nil when closed —
    /// there is nobody to show them to.
    private var menuTicker: Timer?

    /// Which SF Symbol the status item is currently showing, so a hot refresh
    /// can skip rebuilding an identical image.
    private var currentStatusSymbol: String?
    private var currentBoostSymbol: String?

    /// Held so the first-run welcome popover isn't deallocated while shown.
    private var welcomePopover: NSPopover?
    private static let welcomeSeenKey = "com.maxcandela.hasSeenWelcome"

    /// Legal pages on the marketing site. App Store Review Guideline 3.1.2
    /// requires functional Terms of Use + privacy policy links anywhere the
    /// auto-renewable subscription is offered (menu and paywall alert).
    private static let termsURL = URL(string: "https://maxcandela.com/terms/")!
    private static let privacyURL = URL(string: "https://maxcandela.com/privacy/")!
    /// Deliberately the support *page*, not a mailto: — the address can then
    /// change on the site without shipping an app update through review.
    private static let supportURL = URL(string: "https://maxcandela.com/support/")!
    private static let appStoreURL = URL(string: "https://apps.apple.com/us/app/maxcandela/id6792267034?mt=12")!
    /// Apple's redemption page. Used as the fallback for the in-app sheet, and
    /// it covers the case the sheet doesn't: `presentOfferCodeRedeemSheet` takes
    /// *subscription offer codes*, while the promo codes App Store Connect
    /// generates for the lifetime purchase are redeemed here.
    private static let redeemURL = URL(string: "https://apps.apple.com/redeem")!

    /// When the last toggle was applied, so the second click of a double-click
    /// can undo it (see `revertFirstClickToggle`).
    private var lastToggleAppliedAt: Date?
    /// Set when a double-click is detected, so an in-flight entitlement check
    /// doesn't toggle after the user has asked for the menu.
    private var suppressPendingToggle = false

    /// So the trial-ended paywall interrupts once per launch rather than on
    /// every entitlement refresh (every menu open triggers one).
    private var hasShownExpiryPaywall = false

    /// The trial has to end even if nobody touches the app. Enforcement
    /// otherwise only ran at launch and on menu interactions, so a Mac left
    /// running across the expiry moment kept boosting indefinitely.
    private var licenseTimer: Timer?
    private var wakeObserver: NSObjectProtocol?

    /// Last observed license state; refreshed on launch and every menu open.
    private var licenseState: StoreManager.LicenseState = .trial(daysRemaining: StoreManager.shared.trialDaysRemaining)

    init(brightness: BrightnessController) {
        self.brightness = brightness
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.boostItem = NSMenuItem(title: "Turn Boost On", action: nil, keyEquivalent: "b")
        self.headroomItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        self.licenseItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        self.lifetimeItem = NSMenuItem(title: "Unlock Lifetime — $9.99", action: nil, keyEquivalent: "")
        self.monthlyItem = NSMenuItem(title: "Subscribe — $0.99/month", action: nil, keyEquivalent: "")
        self.restoreItem = NSMenuItem(title: "Restore Purchases", action: nil, keyEquivalent: "")
        self.redeemItem = NSMenuItem(title: "Redeem Code…", action: nil, keyEquivalent: "")
        self.menu = NSMenu()

        resolveClickBehaviour()
        configureStatusButton()
        buildMenu()
        // Hide the Notch paints black under the menu bar, so it must know
        // whether the menu bar is drawing dark text — and our status item is
        // the one window that carries the menu bar's appearance.
        for case let desktop as DesktopTool in tools {
            desktop.menuBarAppearance = { [weak self] in self?.statusItem.button?.effectiveAppearance }
        }
        // Battery pause/resume changes the running state with no click.
        brightness.onStateChange = { [weak self] in self?.refresh() }
        hotKey.onPress = { [weak self] in
            // Same path as a click, so the licence gate and the kill-switch
            // rule (off is never gated) apply to the shortcut too.
            self?.suppressPendingToggle = false
            self?.toggleBoost()
        }
        if Preferences.shared.hotKeyEnabled {
            hotKey.register(Preferences.shared.shortcut)
        }
        refresh()
        refreshLicense()
        startLicenseWatch()
        #if DEBUG
        // MAXCANDELA_OPEN_MENU=1 opens the menu by itself shortly after
        // launch, so its layout can be screenshotted without a click.
        if ProcessInfo.processInfo.environment["MAXCANDELA_OPEN_MENU"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.showMenu() }
        }
        runScreenshotModeIfAsked()
        #endif
        showWelcomeIfFirstRun()
    }

    deinit {
        licenseTimer?.invalidate()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }

    /// Re-check the licence periodically and on wake, so an expiry that happens
    /// while the app sits untouched actually stops the boost. Cheap: reading
    /// `Transaction.currentEntitlements` is local, with no network round-trip.
    private func startLicenseWatch() {
        let timer = Timer(timeInterval: 30 * 60, repeats: true) { [weak self] _ in
            self?.refreshLicense()
        }
        RunLoop.main.add(timer, forMode: .common)
        licenseTimer = timer

        // Sleeping through the boundary is the usual way it happens — catch it
        // on wake instead of waiting out the rest of the interval.
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.refreshLicense()
        }
    }

    // MARK: - What a click does

    /// MaxCandela began as a one-button brightness app, where a single click
    /// toggled the boost and the menu was a second gesture. As a toolbox the
    /// menu *is* the app, so new installs open it on a single click.
    ///
    /// People who installed the brightness app keep the click they learned:
    /// having seen the welcome popover is the mark of an existing install, and
    /// this must run before `showWelcomeIfFirstRun()` sets that flag.
    /// Either group can flip it under Options.
    private func resolveClickBehaviour() {
        guard Preferences.shared.clickTogglesBoost == nil else { return }
        let existingInstall = UserDefaults.standard.bool(forKey: Self.welcomeSeenKey)
        Preferences.shared.clickTogglesBoost = Self.initialClickTogglesBoost(existingInstall: existingInstall)
    }

    /// Pure, unit-tested.
    static func initialClickTogglesBoost(existingInstall: Bool) -> Bool { existingInstall }

    private var clickTogglesBoost: Bool { Preferences.shared.clickTogglesBoost ?? false }

    @objc private func toggleClickBehaviour() {
        Preferences.shared.clickTogglesBoost = !clickTogglesBoost
        refresh()
    }

    // MARK: - First-run welcome

    /// On the very first launch, pop a small callout anchored to the ☀️ icon so
    /// the user knows the app lives in the menu bar (there's no window/Dock icon).
    private func showWelcomeIfFirstRun() {
        let defaults = UserDefaults.standard
        #if DEBUG
        // MAXCANDELA_FORCE_WELCOME=1 shows the callout every launch for testing.
        let force = ProcessInfo.processInfo.environment["MAXCANDELA_FORCE_WELCOME"] == "1"
        #else
        let force = false
        #endif
        guard force || !defaults.bool(forKey: Self.welcomeSeenKey) else { return }
        defaults.set(true, forKey: Self.welcomeSeenKey)

        // Defer a beat so the status item is on screen before we anchor to it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self, let button = self.statusItem.button else { return }
            let popover = NSPopover()
            popover.behavior = .transient
            popover.contentViewController = WelcomeViewController(icon: Self.brandIcon, clickTogglesBoost: self.clickTogglesBoost) { [weak self] in
                self?.welcomePopover?.close()
                self?.welcomePopover = nil
            }
            self.welcomePopover = popover
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusButtonClicked)
        // Either button opens the menu — Quit and Restore must never depend on
        // the user knowing to right-click (see the type comment).
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func buildMenu() {
        // Three titled sections — Display, Tools, MaxCandela Pro — then the
        // app-level rows. Every row carries an icon (see MenuStyling).
        menu.addItem(.sectionHeader(title: "Display"))
        boostItem.target = self
        boostItem.action = #selector(toggleBoost)
        menu.addItem(boostItem.symbol("sun.max"))

        headroomItem.isEnabled = false
        menu.addItem(headroomItem.symbol("info.circle"))

        // Extra Dim: slider left = off, right = the dimmest we allow.
        let dimRange = 1.0 - Double(GammaController.minimumDim)
        dimSlider = SliderMenuItemView(
            title: "Extra Dim",
            symbol: "moon",
            value: (1.0 - Double(brightness.extraDim)) / dimRange
        ) { [weak self] value in
            self?.brightness.setExtraDim(CGFloat(1.0 - value * dimRange))
        }
        let dimItem = NSMenuItem()
        dimItem.view = dimSlider
        menu.addItem(dimItem)

        warmthSlider = SliderMenuItemView(
            title: "Warmth",
            symbol: "thermometer.sun",
            value: Double(brightness.warmth)
        ) { [weak self] value in
            self?.brightness.setWarmth(CGFloat(value))
        }
        let warmthItem = NSMenuItem()
        warmthItem.view = warmthSlider
        menu.addItem(warmthItem)

        let scheduleItem = NSMenuItem(title: "Warmth Schedule", action: nil, keyEquivalent: "")
        scheduleItem.submenu = scheduleMenu
        menu.addItem(scheduleItem.symbol("clock"))

        toolSectionStart = menu.items.count
        installToolSection()
        tools.forEach { tool in
            tool.onStatusChange = { [weak self] in self?.refreshStatusText() }
        }
        ProGate.shared.requestUpgrade = { [weak self] in self?.showPaywallAlert() }

        menu.addSection("MaxCandela Pro")
        licenseItem.isEnabled = false
        menu.addItem(licenseItem.symbol("checkmark.seal"))

        lifetimeItem.target = self
        lifetimeItem.action = #selector(buyLifetime)
        menu.addItem(lifetimeItem.symbol("sparkles"))

        monthlyItem.target = self
        monthlyItem.action = #selector(buyMonthly)
        // Guideline 3.1.2: the renewal terms must be visible where the
        // subscription is offered.
        monthlyItem.toolTip = "MaxCandela Pro Monthly — auto-renews every month until cancelled in your App Store account settings."
        menu.addItem(monthlyItem.symbol("calendar"))

        // The three App Store errands live together under one item, the same
        // way Legal groups the two documents. The *buy* items stay at top
        // level — those are the ones that need to be impossible to miss.
        //
        // Restore Purchases being one level down is a considered risk:
        // Guideline 3.1.1 wants it present and reachable, and the 1.0.4
        // rejection was about the whole menu being right-click-only, not about
        // nesting. It stays visible in every licence state (see refresh()).
        let purchasesItem = NSMenuItem(title: "Purchases", action: nil, keyEquivalent: "")
        let purchasesMenu = NSMenu()

        restoreItem.target = self
        restoreItem.action = #selector(restorePurchases)
        purchasesMenu.addItem(restoreItem.symbol("arrow.clockwise"))

        // Redemption previously had no entry point at all — codes worked, but
        // only if the user already knew to go to the App Store app themselves.
        // Hidden once the lifetime unlock is owned (see refresh()).
        redeemItem.target = self
        redeemItem.action = #selector(redeemCode)
        purchasesMenu.addItem(redeemItem.symbol("giftcard"))

        let appStoreItem = NSMenuItem(title: "View in Mac App Store", action: #selector(openAppStore), keyEquivalent: "")
        appStoreItem.target = self
        purchasesMenu.addItem(appStoreItem.symbol("arrow.up.forward.app"))

        purchasesItem.submenu = purchasesMenu
        menu.addItem(purchasesItem.symbol("bag"))

        menu.addItem(.separator())

        // Single "Legal" item; Terms + Privacy + Support live in its submenu
        // (3.1.2 still satisfied — the links stay reachable from the purchase
        // menu).
        let legalItem = NSMenuItem(title: "Legal", action: nil, keyEquivalent: "")
        let legalMenu = NSMenu()
        let termsItem = NSMenuItem(title: "Terms of Use", action: #selector(openTerms), keyEquivalent: "")
        termsItem.target = self
        legalMenu.addItem(termsItem.symbol("doc.text"))
        let privacyItem = NSMenuItem(title: "Privacy Policy", action: #selector(openPrivacy), keyEquivalent: "")
        privacyItem.target = self
        legalMenu.addItem(privacyItem.symbol("hand.raised"))
        // Separated from the two legal documents — it's a help link, not a
        // policy, and the gap keeps that distinction readable.
        legalMenu.addItem(.separator())
        let supportItem = NSMenuItem(title: "Get Support", action: #selector(openSupport), keyEquivalent: "")
        supportItem.target = self
        legalMenu.addItem(supportItem.symbol("questionmark.circle"))
        legalItem.submenu = legalMenu

        // Behaviour switches, all off until the user turns them on.
        let optionsItem = NSMenuItem(title: "Options", action: nil, keyEquivalent: "")
        let optionsMenu = NSMenu()
        clickItem.target = self
        clickItem.action = #selector(toggleClickBehaviour)
        optionsMenu.addItem(clickItem.symbol("cursorarrow.click"))
        batteryItem.target = self
        batteryItem.action = #selector(togglePauseOnBattery)
        optionsMenu.addItem(batteryItem.symbol("battery.50"))
        hotKeyItem.target = self
        hotKeyItem.action = #selector(toggleHotKey)
        optionsMenu.addItem(hotKeyItem.symbol("keyboard"))
        let changeShortcutItem = NSMenuItem(title: "Change Shortcut…", action: #selector(changeShortcut), keyEquivalent: "")
        changeShortcutItem.target = self
        optionsMenu.addItem(changeShortcutItem.symbol("command"))
        let appsItem = NSMenuItem(title: "Boost Only In", action: nil, keyEquivalent: "")
        appsItem.submenu = appsMenu
        optionsMenu.addItem(appsItem.symbol("macwindow"))
        loginItem.target = self
        loginItem.action = #selector(toggleLaunchAtLogin)
        optionsMenu.addItem(loginItem.symbol("power"))
        // Menu Layout: grouped (fits every screen) or every tool in one list.
        let layoutMenu = NSMenu()
        layoutItems = MenuLayout.allCases.map { layout in
            let item = NSMenuItem(title: layout.title, action: #selector(chooseMenuLayout(_:)), keyEquivalent: "")
            item.target = self
            item.toolTip = layout.toolTip
            layoutMenu.addItem(item)
            return (layout, item)
        }
        let layoutItem = NSMenuItem(title: "Menu Layout", action: nil, keyEquivalent: "")
        layoutItem.submenu = layoutMenu
        optionsMenu.addItem(layoutItem.symbol("list.bullet.indent"))
        optionsItem.submenu = optionsMenu
        // Settings before the documents: Options is used, Legal is consulted.
        menu.addItem(optionsItem.symbol("gearshape"))
        menu.addItem(legalItem.symbol("doc.plaintext"))

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit MaxCandela",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q").symbol("xmark.circle"))
    }

    /// The layout in use: the user's choice (Options ▸ Menu Layout), the
    /// flat list by default. DEBUG: `MAXCANDELA_MENU_LAYOUT=flat|grouped` overrides it,
    /// for screenshots.
    private var menuLayout: MenuLayout {
        #if DEBUG
        let override = ProcessInfo.processInfo.environment["MAXCANDELA_MENU_LAYOUT"]
        #else
        let override: String? = nil
        #endif
        return MenuLayout.resolve(stored: Preferences.shared.menuLayout, override: override)
    }

    /// The Pro tools this Mac actually has, as a sentence for the paywall. A
    /// tool hidden here (`isSupported` — e.g. Window Snapping in the sandboxed
    /// build) is never sold. The clipboard manager is the Pro half of the free
    /// Clipboard tool, so it is named separately. Pure, unit-tested.
    static func proToolList(_ titles: [String]) -> String {
        let names = titles.map { $0.replacingOccurrences(of: "…", with: "") } + ["the searchable clipboard history"]
        guard let last = names.last, names.count > 1 else { return names.joined() }
        return names.dropLast().joined(separator: ", ") + " and " + last
    }

    /// The "— Pro" stand-in for a Pro tool, hidden until Pro is unavailable
    /// (see refresh()). Goes right after the tool's own row.
    private func makeLockedRow(for tool: MenuTool) -> NSMenuItem {
        let locked = NSMenuItem(title: "\(tool.menuItem.title) — Pro",
                                action: #selector(showPaywallFromMenu), keyEquivalent: "")
        locked.target = self
        locked.image = tool.menuItem.image
        locked.isHidden = true
        lockedItems.append((tool, locked))
        return locked
    }

    /// Builds the tools section in the current layout and inserts it at
    /// `toolSectionStart`.
    ///  - Grouped (`MenuGroup`): one row per group, each opening its free
    ///    tools and then, under a "Pro" heading, its Pro tools. ~506 pt
    ///    in all — fits every Mac, so Quit never scrolls out of sight.
    ///  - Flat: every tool as its own row, free then Pro. ~997 pt — taller
    ///    than the screen on a 14″ or 13″, where macOS makes it scroll.
    private func installToolSection() {
        var items: [NSMenuItem] = [.separator(), .sectionHeader(title: "Tools")]
        lockedItems.removeAll()
        switch menuLayout {
        case .grouped:
            for group in MenuGroup.allCases {
                let members = tools.filter { MenuGroup.group(forToolNamed: String(describing: type(of: $0))) == group }
                guard !members.isEmpty else { continue }
                let submenu = NSMenu()
                for tool in members where !tool.isPro {
                    submenu.addItem(tool.menuItem)
                }
                let pro = members.filter(\.isPro)
                if !pro.isEmpty {
                    submenu.addSection("Pro")
                    for tool in pro {
                        submenu.addItem(tool.menuItem)
                        submenu.addItem(makeLockedRow(for: tool))
                    }
                }
                groupSubmenus.append(submenu)
                let item = NSMenuItem(title: group.title, action: nil, keyEquivalent: "")
                item.submenu = submenu
                items.append(item.symbol(group.symbol))
            }
            // A tool not yet placed in a group stays visible at the top level.
            for tool in tools where MenuGroup.group(forToolNamed: String(describing: type(of: tool))) == nil {
                items.append(tool.menuItem)
                if tool.isPro { items.append(makeLockedRow(for: tool)) }
            }
        case .flat:
            items += tools.filter { !$0.isPro }.map(\.menuItem)
            items += [.separator(), .sectionHeader(title: "Pro Tools")]
            for tool in tools where tool.isPro {
                items.append(tool.menuItem)
                items.append(makeLockedRow(for: tool))
            }
        }
        for (offset, item) in items.enumerated() {
            menu.insertItem(item, at: toolSectionStart + offset)
        }
        toolSectionItems = items
    }

    /// Re-lays-out the tools section after the user picks a layout. Tool rows
    /// are reused, so each must first leave the menu it is in — an NSMenuItem
    /// can only belong to one menu.
    private func reinstallToolSection() {
        toolSectionItems.forEach { menu.removeItem($0) }
        groupSubmenus.forEach { $0.removeAllItems() }
        groupSubmenus.removeAll()
        installToolSection()
        refresh()
    }

    @objc private func chooseMenuLayout(_ sender: NSMenuItem) {
        guard let choice = layoutItems.first(where: { $0.item === sender })?.layout,
              choice != menuLayout else { return }
        Preferences.shared.menuLayout = choice.rawValue
        reinstallToolSection()
    }

    /// Sync the icon and info lines with the current state.
    private func refresh() {
        // Only when it actually changes: refresh() runs several times a second
        // while the menu is open, and reassigning the image redraws the status
        // item every time for no reason.
        let symbol = brightness.isEnabled ? "sun.max.fill" : "sun.min"
        if symbol != currentStatusSymbol, let button = statusItem.button {
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "MaxCandela")
            button.image?.isTemplate = true
            currentStatusSymbol = symbol
        }
        boostItem.state = brightness.isEnabled ? .on : .off
        // Filled sun while boosting. Only on a change — this is the 5 Hz path.
        let boostSymbol = brightness.isEnabled ? "sun.max.fill" : "sun.max"
        if boostSymbol != currentBoostSymbol {
            boostItem.symbol(boostSymbol)
            currentBoostSymbol = boostSymbol
        }
        let action = brightness.isEnabled ? "Turn Boost Off" : "Turn Boost On"

        // Headroom is per panel, so the figures are too. One display puts its
        // number on the toggle row; several get a row each, because collapsing
        // them into a best-of would report one monitor's ceiling as if it were
        // every monitor's.
        let statuses = brightness.displayStatuses()
        var detail: String?
        var note: String?

        if statuses.isEmpty {
            note = SupportMessages.noHeadroomMenuLine
        } else if statuses.count == 1 {
            detail = Self.remainingText(statuses[0])
        }
        updatePerDisplayItems(statuses.count > 1 ? statuses : [])

        // The second line is for what needs *explaining*, not for restating a
        // number. Thermal state is machine-wide, so it stays a single line.
        if brightness.isEnabled {
            switch brightness.thermalStatus {
            case .normal:
                break
            case .eased:
                note = "Eased for heat"
                detail = detail.map { "\($0) · eased" }
            case .paused:
                detail = nil
                note = "Paused — Mac too hot, resumes when it cools"
            case .dimmed:
                // Below native, so "headroom left" would read as a large number
                // while the screen is darker than normal — report the dim
                // instead. dimTo is machine-wide, so one figure covers all.
                detail = nil
                note = String(format: "Dimmed to %.0f%% — Mac too hot",
                              (statuses.map(\.applied).max() ?? 1.0) * 100)
            }
        }

        // The saved boost is being held off for the power source — say so, or
        // an "off" icon with the boost supposedly left on looks like a fault.
        if brightness.pausedForBattery {
            note = "Paused on battery — resumes when plugged in"
        } else if brightness.pausedForApp {
            note = "Waiting for one of your chosen apps"
        }
        hotKeyItem.title = "Shortcut \(Preferences.shared.shortcut.display) Toggles Boost"

        clickItem.state = clickTogglesBoost ? .on : .off
        let layout = menuLayout
        layoutItems.forEach { $0.item.state = $0.layout == layout ? .on : .off }
        batteryItem.state = brightness.pauseOnBattery ? .on : .off
        hotKeyItem.state = hotKey.isRegistered ? .on : .off

        // Warmth is Pro, like the boost. Expired, it is already back at native
        // (BrightnessController.suspendForLicense), so its slider is disabled
        // rather than left to do nothing. Extra Dim is free: always enabled.
        dimSlider.isEnabled = true
        warmthSlider.isEnabled = licenseState != .expired
        for entry in lockedItems {
            entry.tool.menuItem.isHidden = !ProGate.shared.isAllowed
            entry.locked.isHidden = ProGate.shared.isAllowed
        }

        setBoostTitle(action, detail: detail)
        headroomItem.title = note ?? ""
        headroomItem.isHidden = note == nil

        switch licenseState {
        case .licensed:
            licenseItem.title = "MaxCandela Pro — unlocked"
            [lifetimeItem, monthlyItem].forEach { $0.isHidden = true }
            // Guideline 3.1.1: Restore Purchases stays visible at all times,
            // including when already unlocked.
            restoreItem.isHidden = false
            statusItem.button?.toolTip = "MaxCandela Pro"
        case .trial(let days):
            let dayText = "\(days) day\(days == 1 ? "" : "s")"
            licenseItem.title = "Free trial — \(dayText) left"
            [lifetimeItem, monthlyItem, restoreItem].forEach { $0.isHidden = false }
            // Hover tooltip so the countdown is visible without opening the menu.
            statusItem.button?.toolTip = "MaxCandela — \(dayText) left in your free trial"
        case .expired:
            licenseItem.title = "Trial ended — Pro tools are locked"
            [lifetimeItem, monthlyItem, restoreItem].forEach { $0.isHidden = false }
            statusItem.button?.toolTip = "MaxCandela — free trial ended"
        }

        // Nothing left to redeem once the lifetime unlock is owned, however it
        // was obtained — purchase or IAP promo code. Deliberately keyed on the
        // lifetime entitlement rather than on `.licensed`: a *subscriber* is
        // licensed too, and subscription offer codes (the only kind the in-app
        // sheet accepts) are exactly what they might still want to redeem.
        redeemItem.isHidden = store.ownsLifetime
    }

    /// How much lift this panel has left, or nil when live headroom is still
    /// sitting at its EDR-disengaged ~1.0 and would only mislead.
    private static func remainingText(_ status: BrightnessController.DisplayStatus) -> String? {
        guard status.isMeaningful else { return nil }
        return String(format: "%.2f× left", status.remaining)
    }

    @objc private func toggleDisplayBoost(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        // state .on == currently boosted, so a click takes it out.
        brightness.setDisplay(id, boosted: sender.state != .on)
        refresh()
    }

    /// One row per display, directly under the toggle.
    ///
    /// Rows are only inserted/removed when the set of displays actually
    /// changes; otherwise they are retitled in place. This runs several times a
    /// second while the menu is open, and removing an item from a menu the user
    /// is looking at makes it flicker and can drop the highlight.
    private func updatePerDisplayItems(_ statuses: [BrightnessController.DisplayStatus]) {
        let names = statuses.map(\.name)
        if names != perDisplayNames {
            perDisplayItems.forEach(menu.removeItem)
            perDisplayItems = []
            perDisplayNames = names

            let anchor = menu.index(of: boostItem)
            guard !statuses.isEmpty, anchor >= 0 else { return }

            for (offset, _) in statuses.enumerated() {
                // Clickable: each row is that display's own boost switch.
                let item = NSMenuItem(title: "", action: #selector(toggleDisplayBoost(_:)), keyEquivalent: "")
                item.target = self
                item.indentationLevel = 1
                menu.insertItem(item, at: anchor + 1 + offset)
                perDisplayItems.append(item)
            }
        }

        for (item, status) in zip(perDisplayItems, statuses) {
            item.representedObject = status.id
            item.state = status.isExcluded ? .off : .on
            if status.isExcluded {
                item.title = "\(status.name) — not boosted"
            } else {
                item.title = Self.remainingText(status).map { "\(status.name) — \($0)" } ?? status.name
            }
        }
    }

    /// Render the boost row as "Turn Boost Off   3.98×", with the figure in
    /// secondary colour so the action still reads first. Plain `title` is kept
    /// in sync for accessibility, which ignores `attributedTitle`.
    private func setBoostTitle(_ action: String, detail: String?) {
        guard let detail else {
            boostItem.attributedTitle = nil
            boostItem.title = action
            return
        }
        boostItem.title = "\(action) — \(detail)"
        let font = NSFont.menuFont(ofSize: 0)
        let title = NSMutableAttributedString(
            string: action,
            attributes: [.font: font, .foregroundColor: NSColor.labelColor])
        title.append(NSAttributedString(
            string: "   \(detail)",
            attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor]))
        boostItem.attributedTitle = title
    }

    /// Text beside the status icon — a running timer's countdown. Only
    /// written when it changes; a status item that re-lays-out every second
    /// for an identical title makes its neighbours in the menu bar twitch.
    private func refreshStatusText() {
        guard let button = statusItem.button else { return }
        let text = tools.compactMap(\.statusText).joined(separator: " ")
        guard button.title != text else { return }
        button.title = text
        button.imagePosition = text.isEmpty ? .imageOnly : .imageLeading
        // Fixed-width digits, or the countdown shifts the menu bar each second.
        button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    }

    /// Called at quit: let every tool release what it holds.
    func shutdown() {
        tools.forEach { $0.shutdown() }
    }

    /// External license changes (renewal, refund, purchase on another Mac).
    func licenseDidChange() {
        refreshLicense()
    }

    /// Act on the resolved licence state: restore the boost the user left on,
    /// or stop it if the trial has run out.
    ///
    /// This is what makes the trial actually end. Before it existed the boost
    /// was restored straight from `BrightnessController.init` with no
    /// entitlement check, so anyone who simply left it switched on kept full
    /// brightness forever and never saw the paywall again.
    private func enforceLicense() {
        switch licenseState {
        case .licensed, .trial:
            ProGate.shared.set(allowed: true)
            brightness.setLicensed()
            brightness.restorePersistedBoostIfWanted()
        case .expired:
            ProGate.shared.set(allowed: false)
            let wasBoosting = brightness.isEnabled || brightness.wantsPersistedBoost
            brightness.suspendForLicense()
            // Interrupt once per launch, not on every entitlement refresh.
            if wasBoosting && !hasShownExpiryPaywall {
                hasShownExpiryPaywall = true
                showPaywallAlert()
            }
        }
    }

    /// Re-check entitlements and localized prices off the main thread.
    private func refreshLicense() {
        Task { @MainActor in
            licenseState = await store.currentState()
            ConversionTracker.update(licenseState: licenseState)
            enforceLicense()
            await store.loadProducts()
            if let lifetime = store.product(id: StoreManager.lifetimeProductID) {
                lifetimeItem.title = "Unlock Lifetime — \(lifetime.displayPrice)"
            }
            if let monthly = store.product(id: StoreManager.monthlyProductID) {
                monthlyItem.title = "Subscribe — \(monthly.displayPrice)/month"
            }
            refresh()
        }
    }

    // MARK: - Actions

    @objc private func statusButtonClicked() {
        guard let event = NSApp.currentEvent else { return }

        // Right-click / Control-click: always the menu.
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu()
            return
        }

        // Toolbox behaviour: the click opens the menu, where the boost is the
        // first row (and ⌘B while the menu is open).
        if !clickTogglesBoost {
            showMenu()
            return
        }

        // Nothing to toggle on this display, so a toggle would be a dead end —
        // give the user the menu (with Quit and Restore) instead. This is also
        // the App Review path: their MacBook Air has no headroom, so a single
        // click still lands them somewhere useful.
        if !brightness.canBoost() {
            showMenu()
            return
        }

        // Second click of a double-click: the user wanted the menu, not a
        // toggle. Undo what the first click did rather than making them
        // click again. Deliberately no delay on the single click — waiting
        // out the double-click interval would make every toggle feel laggy.
        if event.clickCount >= 2 {
            suppressPendingToggle = true
            revertFirstClickToggle()
            showMenu()
            return
        }

        suppressPendingToggle = false
        toggleBoost()
    }

    /// Undo a toggle applied moments ago by the first click of a double-click.
    private func revertFirstClickToggle() {
        guard let applied = lastToggleAppliedAt,
              Date().timeIntervalSince(applied) < NSEvent.doubleClickInterval + 0.25
        else { return }
        lastToggleAppliedAt = nil
        brightness.toggle()
        refresh()
    }

    @objc private func toggleBoost() {
        // Turning OFF is always allowed — the kill switch never sits behind
        // the paywall. Turning ON requires a valid trial or license.
        if brightness.isEnabled {
            brightness.toggle()
            lastToggleAppliedAt = Date()
            refresh()
            return
        }
        // No EDR headroom on this display → there's nothing to boost. Explain
        // rather than flip to a fake "on" state that does nothing.
        if !brightness.canBoost() {
            showNoHeadroomAlert()
            return
        }
        Task { @MainActor in
            licenseState = await store.currentState()
            // A second click landed while the entitlement check was in flight —
            // the user asked for the menu, so don't toggle behind them.
            guard !suppressPendingToggle else { return }
            switch licenseState {
            case .licensed, .trial:
                // Only ever switches ON from here — this branch began with
                // the boost off. A launch-time licence check can restore the
                // saved boost while this one is in flight, and a blind
                // toggle would then turn it straight back off.
                brightness.setLicensed()
                if !brightness.isEnabled {
                    brightness.toggle()
                    lastToggleAppliedAt = Date()
                    refresh()
                    showM5NoticeIfNeeded()
                    ReviewPrompt.boostWasSwitchedOn(license: licenseState)
                }
            case .expired:
                showPaywallAlert()
            }
            refresh()
        }
    }

    /// Shortcuts actions and `maxcandela://` links (see `BoostAutomation`).
    /// The click's rules — off is never gated; on needs headroom and the
    /// licence — minus everything that would put a dialog in front of someone
    /// who may not be there: no paywall, no no-headroom alert, no M5 notice,
    /// no rating prompt. Those wait for a real click.
    @MainActor
    func setBoostFromAutomation(_ command: BoostCommand) async -> BoostOutcome {
        let wantOn: Bool
        switch command {
        case .on: wantOn = true
        case .off: wantOn = false
        case .toggle: wantOn = !brightness.isEnabled
        }
        if !wantOn {
            if brightness.isEnabled {
                brightness.toggle()
                refresh()
            }
            return .off
        }
        if brightness.isEnabled { return .on }
        guard brightness.canBoost() else { return .noHeadroom }
        licenseState = await store.currentState()
        switch licenseState {
        case .licensed, .trial:
            brightness.setLicensed()
            // Re-checked after the await: a launch-time licence check may have
            // restored the saved boost meanwhile, and toggle() would undo it.
            if !brightness.isEnabled {
                brightness.toggle()
            }
            refresh()
            return .on
        case .expired:
            refresh()
            return .needsPro
        }
    }

    private func showMenu() {
        refreshLicense()
        // Read from the system once per open, not in refresh(): the user can
        // change it in System Settings, and refresh() is a 5 Hz hot path.
        loginItem.state = LoginItem.isEnabled ? .on : .off
        rebuildScheduleMenu()
        rebuildAppsMenu()
        tools.forEach { $0.menuWillOpen() }
        refresh()
        // Assign the menu just long enough to pop it up, then detach so the
        // next click keeps reaching statusButtonClicked (a permanently
        // attached menu hijacks the click before we can refresh its contents).
        statusItem.menu = menu
        // performClick runs the menu's tracking loop synchronously, so these
        // two lines bracket exactly the window in which the menu is on screen.
        startMenuTicker()
        statusItem.button?.performClick(nil)
        stopMenuTicker()
        statusItem.menu = nil
    }

    /// Keep the figures live while the menu is open, so changing brightness
    /// with the keys updates the row instead of leaving a snapshot from
    /// whenever the menu happened to open.
    ///
    /// Must be added in `.common` modes: menu tracking runs the run loop in
    /// event-tracking mode, where a default-mode timer never fires — the whole
    /// point of this timer is the one situation a plain `scheduledTimer` sleeps
    /// through.
    private func startMenuTicker() {
        menuTicker?.invalidate()
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.refresh()
            self?.tools.forEach { $0.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        menuTicker = timer
    }

    private func stopMenuTicker() {
        menuTicker?.invalidate()
        menuTicker = nil
    }

    /// The MaxCandela logo for dialogs. Loaded from the bundled resource so it
    /// shows even under `swift run` (a bare binary otherwise has no app icon,
    /// so NSAlert falls back to a generic file/document icon). Falls back to the
    /// app icon in a normal bundled launch.
    private static let brandIcon: NSImage? = {
        #if SWIFT_PACKAGE
        // `swift run` has no app icon, so load the bundled resource explicitly.
        // Not inside a .app, though: scripts/bundle-macos.sh ships the binary
        // without SwiftPM's resource bundle, and the generated `Bundle.module`
        // accessor calls fatalError when it can't find one — it only appeared
        // to work on the Mac that built it, via an absolute .build/ fallback
        // path. That bundle has a real icon (AppIcon.icns) anyway.
        if Bundle.main.bundleURL.pathExtension != "app",
           let url = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        #endif
        // Xcode/App Store build: the asset-catalog app icon is the real thing.
        return NSApp.applicationIconImage
    }()

    @objc private func showPaywallFromMenu() { showPaywallAlert() }

    private func showPaywallAlert() {
        Analytics.track("paywall_shown")
        let alert = NSAlert()
        alert.icon = Self.brandIcon
        alert.messageText = "Your free trial has ended"
        // Guideline 3.1.2: title, length, and price of each purchase, spelled
        // out, with the renewal terms. Localized prices when the store loaded.
        let lifetimePrice = store.product(id: StoreManager.lifetimeProductID)?.displayPrice ?? "$9.99"
        let monthlyPrice = store.product(id: StoreManager.monthlyProductID)?.displayPrice ?? "$0.99"
        alert.informativeText = """
        MaxCandela Pro unlocks the XDR brightness boost, Warmth and the Pro tools: \(Self.proToolList(tools.filter(\.isPro).map(\.menuItem.title))). Extra Dim and the everyday tools stay free. One purchase works on all your Macs.

        MaxCandela Pro Lifetime — \(lifetimePrice), one-time purchase.

        MaxCandela Pro Monthly — \(monthlyPrice) per month. Auto-renews every month until cancelled in your App Store account settings.
        """
        alert.accessoryView = Self.makeLegalLinksView()
        alert.addButton(withTitle: "Unlock Lifetime")
        alert.addButton(withTitle: "Subscribe Monthly")
        alert.addButton(withTitle: "Not Now")
        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn: buyLifetime()
        case .alertSecondButtonReturn: buyMonthly()
        default: break
        }
    }

    /// Clickable Terms of Use / Privacy Policy links shown under the paywall
    /// text (Guideline 3.1.2 requires both wherever the subscription is sold).
    private static func makeLegalLinksView() -> NSView {
        let base: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        func link(_ title: String, _ url: URL) -> NSAttributedString {
            var attrs = base
            attrs[.link] = url
            return NSAttributedString(string: title, attributes: attrs)
        }
        let text = NSMutableAttributedString()
        text.append(link("Terms of Use", termsURL))
        text.append(NSAttributedString(string: "   ·   ", attributes: base))
        text.append(link("Privacy Policy", privacyURL))

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 240, height: 16))
        textView.textStorage?.setAttributedString(text)
        textView.alignment = .center
        textView.isEditable = false
        textView.isSelectable = true // links are only clickable when selectable
        textView.drawsBackground = false
        return textView
    }

    private func showNoHeadroomAlert() {
        let alert = NSAlert()
        alert.icon = Self.brandIcon
        alert.messageText = SupportMessages.noHeadroomTitle
        alert.informativeText = SupportMessages.noHeadroomBody
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    /// One-time heads-up on the chips where macOS is reported to ignore the
    /// gamma lift (see KnownIssues). Shown *after* switching on, so the user
    /// can judge the screen against what the text says, and never blocks it.
    private func showM5NoticeIfNeeded() {
        guard KnownIssues.gammaLiftReportedBroken, !Preferences.shared.m5NoticeSeen else { return }
        Preferences.shared.m5NoticeSeen = true
        let alert = NSAlert()
        alert.icon = Self.brandIcon
        alert.messageText = SupportMessages.m5IssueTitle
        alert.informativeText = SupportMessages.m5IssueBody
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Get Support")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertSecondButtonReturn {
            NSWorkspace.shared.open(Self.supportURL)
        }
    }

    @objc private func togglePauseOnBattery() {
        brightness.pauseOnBattery.toggle()
        refresh()
    }

    @objc private func toggleHotKey() {
        let shortcut = Preferences.shared.shortcut
        if hotKey.isRegistered {
            hotKey.unregister()
            Preferences.shared.hotKeyEnabled = false
        } else if hotKey.register(shortcut) {
            Preferences.shared.hotKeyEnabled = true
        } else {
            showShortcutUnavailableAlert(shortcut)
        }
        refresh()
    }

    private func showShortcutUnavailableAlert(_ shortcut: Shortcut) {
        showOptionFailedAlert(
            title: "Shortcut unavailable",
            body: "\(shortcut.display) could not be registered — another app is probably using it.")
    }

    /// Record a new shortcut. Choosing one also switches the shortcut on —
    /// nobody records a shortcut they then want disabled.
    @objc private func changeShortcut() {
        let previous = Preferences.shared.shortcut
        let recorder = ShortcutRecorderView(shortcut: previous)
        let alert = NSAlert()
        alert.icon = Self.brandIcon
        alert.messageText = "Press the shortcut you want"
        alert.informativeText = "Use ⌘, ⌃ or ⌥ with another key. It will toggle the boost from any app."
        alert.accessoryView = recorder
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = recorder
        // Our own shortcut must not fire (and toggle the boost) while the
        // user is pressing it into the recorder.
        let wasRegistered = hotKey.isRegistered
        hotKey.unregister()
        NSApp.activate(ignoringOtherApps: true)
        let saved = alert.runModal() == .alertFirstButtonReturn

        let chosen = saved ? recorder.shortcut : previous
        if saved || wasRegistered {
            if hotKey.register(chosen) {
                Preferences.shared.shortcut = chosen
                Preferences.shared.hotKeyEnabled = true
            } else {
                showShortcutUnavailableAlert(chosen)
                // Fall back to what worked before rather than leaving none.
                if wasRegistered { hotKey.register(previous) }
            }
        }
        refresh()
    }

    // MARK: - Warmth schedule

    private static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("j")   // "8 PM" or "20"
        return formatter
    }()

    private static func hourTitle(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return hourFormatter.string(from: date)
    }

    private func rebuildScheduleMenu() {
        let schedule = brightness.warmthSchedule
        scheduleMenu.removeAllItems()

        let always = NSMenuItem(title: "Always On", action: #selector(setScheduleMode(_:)), keyEquivalent: "")
        always.target = self
        always.tag = 0
        always.state = schedule.enabled ? .off : .on
        scheduleMenu.addItem(always)

        let night = NSMenuItem(
            title: "Only at Night (\(Self.hourTitle(schedule.startHour)) – \(Self.hourTitle(schedule.endHour)))",
            action: #selector(setScheduleMode(_:)), keyEquivalent: "")
        night.target = self
        night.tag = 1
        night.state = schedule.enabled ? .on : .off
        scheduleMenu.addItem(night)

        scheduleMenu.addItem(.separator())
        // Evening hours to start, morning hours to end: every combination is
        // a real night, so there is no invalid window to guard against.
        scheduleMenu.addItem(hourSubmenu(title: "Starts", hours: Array(16...23),
                                         selected: schedule.startHour,
                                         action: #selector(setScheduleStart(_:))))
        scheduleMenu.addItem(hourSubmenu(title: "Ends", hours: Array(4...10),
                                         selected: schedule.endHour,
                                         action: #selector(setScheduleEnd(_:))))
    }

    private func hourSubmenu(title: String, hours: [Int], selected: Int, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for hour in hours {
            let row = NSMenuItem(title: Self.hourTitle(hour), action: action, keyEquivalent: "")
            row.target = self
            row.tag = hour
            row.state = hour == selected ? .on : .off
            submenu.addItem(row)
        }
        item.submenu = submenu
        return item
    }

    @objc private func setScheduleMode(_ sender: NSMenuItem) {
        brightness.warmthSchedule.enabled = sender.tag == 1
    }

    // Picking an hour is also choosing to use the schedule.
    @objc private func setScheduleStart(_ sender: NSMenuItem) {
        var schedule = brightness.warmthSchedule
        schedule.startHour = sender.tag
        schedule.enabled = true
        brightness.warmthSchedule = schedule
    }

    @objc private func setScheduleEnd(_ sender: NSMenuItem) {
        var schedule = brightness.warmthSchedule
        schedule.endHour = sender.tag
        schedule.enabled = true
        brightness.warmthSchedule = schedule
    }

    // MARK: - Boost only in chosen apps

    /// Chosen apps on top (click to remove), then the running apps to add.
    /// Picking from what is running avoids a file dialog — and with it the
    /// sandbox's user-selected-file entitlement.
    private func rebuildAppsMenu() {
        let chosen = brightness.boostApps
        appsMenu.removeAllItems()

        if chosen.isEmpty {
            let all = NSMenuItem(title: "Every App (no restriction)", action: nil, keyEquivalent: "")
            all.isEnabled = false
            all.state = .on
            appsMenu.addItem(all)
        }
        for (bundleID, name) in chosen.sorted(by: { $0.value.localizedCaseInsensitiveCompare($1.value) == .orderedAscending }) {
            let item = NSMenuItem(title: name, action: #selector(removeBoostApp(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = bundleID
            item.state = .on
            item.toolTip = "Click to remove"
            appsMenu.addItem(item)
        }

        let ownPID = ProcessInfo.processInfo.processIdentifier
        let running = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != ownPID }
            .compactMap { app -> (id: String, name: String)? in
                guard let id = app.bundleIdentifier, chosen[id] == nil else { return nil }
                return (id, app.localizedName ?? id)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        guard !running.isEmpty else { return }

        appsMenu.addItem(.separator())
        let header = NSMenuItem(title: "Add a Running App", action: nil, keyEquivalent: "")
        header.isEnabled = false
        appsMenu.addItem(header)
        for app in running {
            let item = NSMenuItem(title: app.name, action: #selector(addBoostApp(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = [app.id, app.name]
            item.indentationLevel = 1
            appsMenu.addItem(item)
        }
    }

    @objc private func addBoostApp(_ sender: NSMenuItem) {
        guard let pair = sender.representedObject as? [String], pair.count == 2 else { return }
        brightness.boostApps[pair[0]] = pair[1]
        refresh()
    }

    @objc private func removeBoostApp(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        brightness.boostApps[bundleID] = nil
        refresh()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            try LoginItem.setEnabled(!LoginItem.isEnabled)
        } catch {
            NSLog("MaxCandela: launch at login failed: \(error.localizedDescription)")
            showOptionFailedAlert(
                title: "Couldn’t change Launch at Login",
                body: "macOS reported: \(error.localizedDescription)\n\nYou can also add MaxCandela under System Settings ▸ General ▸ Login Items.")
        }
        loginItem.state = LoginItem.isEnabled ? .on : .off
    }

    private func showOptionFailedAlert(title: String, body: String) {
        let alert = NSAlert()
        alert.icon = Self.brandIcon
        alert.messageText = title
        alert.informativeText = body
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func buyLifetime() { purchase(productID: StoreManager.lifetimeProductID) }
    @objc private func buyMonthly() { purchase(productID: StoreManager.monthlyProductID) }
    @objc private func openTerms() { NSWorkspace.shared.open(Self.termsURL) }
    @objc private func openPrivacy() { NSWorkspace.shared.open(Self.privacyURL) }
    @objc private func openSupport() { NSWorkspace.shared.open(Self.supportURL) }
    @objc private func openAppStore() { NSWorkspace.shared.open(Self.appStoreURL) }

    private func purchase(productID: String) {
        Task { @MainActor in
            await store.loadProducts()
            guard let product = store.product(id: productID) else {
                showStoreUnavailableAlert()
                return
            }
            // An accessory app is never "active", and macOS parks the StoreKit
            // payment sheet behind other windows unless the app is — activate
            // first so the sheet actually appears in front of the user.
            NSApp.activate(ignoringOtherApps: true)
            // Anchor the sheet to an invisible centered window so it opens in
            // the middle of the screen instead of a system-guessed corner.
            let anchor = Self.makePurchaseAnchor()
            Self.centerAttachedSheet(on: anchor)
            defer { anchor?.close() }
            do {
                if try await store.purchase(product, confirmIn: anchor) {
                    licenseState = .licensed
                    // Bring back a boost the expiry suspended. A purchase
                    // made here never arrives on Transaction.updates, so
                    // nothing else would until the next licence refresh —
                    // the user would pay and see no change.
                    enforceLicense()
                    refresh()
                    Analytics.track("purchase_completed", params: ["product": productID])
                    ConversionTracker.update(licenseState: .licensed)
                }
            } catch {
                NSLog("MaxCandela: purchase failed: \(error.localizedDescription)")
                showPurchaseFailedAlert(error)
            }
        }
    }

    /// Redeem a promo / offer code. The native sheet keeps the user in the app
    /// where it's available; everything else falls through to Apple's
    /// redemption page, which also handles IAP promo codes the sheet won't.
    @objc private func redeemCode() {
        Task { @MainActor in
            NSApp.activate(ignoringOtherApps: true)
            // macOS 15+ only, and the SwiftPM dev build targets 14 — the
            // shipping Xcode build (15.6) always takes the sheet path.
            if #available(macOS 15.0, *) {
                let anchor = Self.makePurchaseAnchor()
                let host = NSViewController()
                host.view = NSView(frame: NSRect(x: 0, y: 0, width: 2, height: 2))
                anchor?.contentViewController = host
                Self.centerAttachedSheet(on: anchor)
                defer { anchor?.close() }
                do {
                    try await AppStore.presentOfferCodeRedeemSheet(from: host)
                    // The entitlement also arrives via Transaction.updates, but
                    // refresh now so the menu is right as the sheet closes.
                    refreshLicense()
                    return
                } catch {
                    NSLog("MaxCandela: offer code sheet unavailable: \(error.localizedDescription)")
                }
            }
            NSWorkspace.shared.open(Self.redeemURL)
        }
    }

    @objc private func restorePurchases() {
        Task { @MainActor in
            await store.restorePurchases()
            ConversionTracker.syncPurchases()
            refreshLicense()
        }
    }

    /// A tiny invisible window centered on the main screen, used purely as the
    /// anchor for the StoreKit purchase and offer-code sheets.
    private static func makePurchaseAnchor() -> NSWindow? {
        // The screen the user is actually on — they just clicked the status
        // item, so the pointer is the best signal. NSScreen.main follows the
        // key window, which an accessory app doesn't have.
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) })
                ?? NSScreen.main
        else { return nil }
        let bounds = screen.frame
        // Base designated init only — the screen: variant traps in subclasses
        // on newer macOS (see CLAUDE.md gotchas); global coordinates instead.
        // Starting position only; centerAttachedSheet does the real work once
        // the sheet exists and its size is known.
        let window = NSWindow(
            contentRect: NSRect(x: bounds.midX - 1, y: bounds.midY, width: 2, height: 2),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.orderFrontRegardless()
        return window
    }

    /// Keep whatever sheet StoreKit attaches to `anchor` centred on the screen.
    ///
    /// A sheet hangs from its parent window's top edge, so a fixed anchor
    /// position only centres a sheet of one particular size. Instead the anchor
    /// is shifted by the measured error once the sheet exists; the sheet tracks
    /// its parent, so it moves with it.
    ///
    /// This keeps watching rather than correcting once. StoreKit's sheets are
    /// remote views whose content loads asynchronously (the redeem sheet is a
    /// web view), so they *resize after presenting* — a single correction
    /// measures the pre-load size and leaves the finished sheet off-centre.
    /// Re-centring on every size change is what actually holds it in the
    /// middle. Runs ~5 s, then gives up quietly.
    private static func centerAttachedSheet(on anchor: NSWindow?,
                                            lastSize: CGSize = .zero,
                                            attemptsLeft: Int = 100) {
        guard let anchor, attemptsLeft > 0 else { return }

        var seen = lastSize
        if let sheet = hostedWindow(of: anchor), sheet.frame.size != lastSize {
            seen = sheet.frame.size
            recenter(sheet, parent: anchor)
            NSLog("MaxCandela: centred StoreKit window, size %@ → %@",
                  NSStringFromSize(sheet.frame.size), NSStringFromRect(sheet.frame))
        }
        // One survey mid-flight, so a sheet we failed to find can still be
        // identified from the log instead of guessing at its window class.
        if attemptsLeft == 80 {
            let others = NSApp.windows
                .filter { $0 !== anchor && $0.isVisible }
                .map { "\(type(of: $0)) \(NSStringFromRect($0.frame))" }
            NSLog("MaxCandela: redeem survey — attachedSheet=%@ children=%d visibleWindows=[%@]",
                  anchor.attachedSheet == nil ? "nil" : "yes",
                  anchor.childWindows?.count ?? 0,
                  others.joined(separator: ", "))
        }
        guard attemptsLeft > 1 else {
            // Whether StoreKit's remote UI is reachable as a sheet or child
            // window at all is the one thing this code can't assume. If it is
            // not, nothing above runs and Apple positions it — say so in the
            // log rather than failing silently.
            if seen == .zero {
                NSLog("MaxCandela: no hosted window seen — StoreKit positioned it itself")
            }
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            centerAttachedSheet(on: anchor, lastSize: seen, attemptsLeft: attemptsLeft - 1)
        }
    }

    /// The window StoreKit put on top of `anchor`, if we can reach it at all.
    ///
    /// `attachedSheet` covers a true sheet (the payment sheet). The offer-code
    /// sheet is drawn by `StoreKitUIServiceMac` out of process and was observed
    /// *not* to register there, so a child window is checked too. If neither
    /// finds it, the window belongs to another process and the sandbox gives us
    /// no supported way to move it.
    private static func hostedWindow(of anchor: NSWindow) -> NSWindow? {
        anchor.attachedSheet ?? anchor.childWindows?.first { $0.isVisible }
    }

    /// Move `parent` so its sheet lands in the middle of the monitor — the
    /// full `frame`, not `visibleFrame`, so the result is optically centred
    /// rather than nudged by whichever edge the Dock happens to occupy. Only
    /// clamped back if the sheet is too tall to fit the usable area.
    private static func recenter(_ sheet: NSWindow, parent: NSWindow) {
        guard let screen = parent.screen ?? NSScreen.main else { return }
        let bounds = screen.frame
        let visible = screen.visibleFrame

        var target = sheet.frame
        target.origin.x = bounds.midX - target.width / 2
        target.origin.y = bounds.midY - target.height / 2
        if target.maxY > visible.maxY { target.origin.y = visible.maxY - target.height }
        if target.minY < visible.minY { target.origin.y = visible.minY }

        let dx = target.origin.x - sheet.frame.origin.x
        let dy = target.origin.y - sheet.frame.origin.y
        guard abs(dx) > 0.5 || abs(dy) > 0.5 else { return }

        var frame = parent.frame
        frame.origin.x += dx
        frame.origin.y += dy
        parent.setFrame(frame, display: false)
    }

    private func showPurchaseFailedAlert(_ error: Error) {
        let alert = NSAlert()
        alert.icon = Self.brandIcon
        alert.messageText = "Purchase didn’t go through"
        alert.informativeText = "The App Store reported: \(error.localizedDescription)\n\nNothing was charged. Please try again."
        alert.addButton(withTitle: "OK")
        // Money is involved here — offer a way to reach a human directly.
        alert.addButton(withTitle: "Get Support")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertSecondButtonReturn {
            NSWorkspace.shared.open(Self.supportURL)
        }
    }

    private func showStoreUnavailableAlert() {
        let alert = NSAlert()
        alert.icon = Self.brandIcon
        alert.messageText = "App Store unavailable"
        alert.informativeText = "Products could not be loaded. Check your internet connection and try again."
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

#if DEBUG
// MARK: - Screenshot mode (scripts/make-app-screenshots.sh)

/// Captures of the *real* menus for the App Store screenshots, without any of
/// the user's desktop in them.
///
/// `MAXCANDELA_SHOT=<main|ToolTypeName>` covers the whole screen — menu bar
/// and Dock included — with an opaque backdrop in the screenshots' background
/// colour, opens the requested menu on top of it, writes the menu's on-screen
/// rectangle to `MAXCANDELA_SHOT_OUT`, holds for a moment so the script can
/// capture exactly that rectangle, then quits. Nothing behind the backdrop
/// can end up in the picture.
extension MenuBarController {
    /// Must match `background` in scripts/make-app-screenshots.swift, so a
    /// captured menu (and its shadow) drops onto the canvas without a seam.
    static let screenshotBackdrop = NSColor(srgbRed: 0.047, green: 0.063, blue: 0.086, alpha: 1)

    fileprivate func runScreenshotModeIfAsked() {
        let environment = ProcessInfo.processInfo.environment
        guard let shot = environment["MAXCANDELA_SHOT"],
              let out = environment["MAXCANDELA_SHOT_OUT"],
              let screen = NSScreen.main else { return }

        let backdrop = NSWindow(contentRect: screen.frame, styleMask: .borderless,
                                backing: .buffered, defer: false)
        backdrop.backgroundColor = Self.screenshotBackdrop
        backdrop.isOpaque = true
        // Above the menu bar and the Dock, one level below menus.
        backdrop.level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue - 1)
        backdrop.isReleasedWhenClosed = false
        backdrop.orderFrontRegardless()
        screenshotBackdropWindow = backdrop

        // The menu's tracking loop blocks, so both timers must be in .common
        // modes or they would sleep through exactly the moment they exist for.
        let report = Timer(timeInterval: 2.6, repeats: false) { _ in
            let pid = ProcessInfo.processInfo.processIdentifier
            let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
            let menus = windows.filter {
                ($0[kCGWindowOwnerPID as String] as? Int32) == pid
                    && ($0[kCGWindowLayer as String] as? Int) == Int(NSWindow.Level.popUpMenu.rawValue)
            }.compactMap { ($0[kCGWindowBounds as String] as? NSDictionary).flatMap { CGRect(dictionaryRepresentation: $0) } }
            guard let bounds = menus.reduce(nil as CGRect?, { $0?.union($1) ?? $1 }) else { return }
            let text = "\(Int(bounds.minX)) \(Int(bounds.minY)) \(Int(bounds.width)) \(Int(bounds.height))"
            try? text.write(toFile: out, atomically: true, encoding: .utf8)
        }
        RunLoop.main.add(report, forMode: .common)
        let finish = Timer(timeInterval: 5.5, repeats: false) { [weak self] _ in
            // An open menu holds the run loop in its tracking mode; close it
            // or terminate() waits for a click that never comes. exit() is
            // the backstop — a backdrop stuck over the screen is the one
            // failure this mode must not have.
            self?.menu.cancelTracking()
            self?.tools.forEach { $0.menuItem.submenu?.cancelTracking() }
            self?.menu.items.forEach { $0.submenu?.cancelTracking() }
            self?.brightness.shutdown()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { exit(0) }
        }
        RunLoop.main.add(finish, forMode: .common)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }
            // MAXCANDELA_SHOT_RELAYOUT=1 rebuilds the tools section twice
            // first — the path Options ▸ Menu Layout takes — so a row left in
            // its old menu (an AppKit exception) shows up here, not in use.
            if environment["MAXCANDELA_SHOT_RELAYOUT"] == "1" {
                self.reinstallToolSection()
                self.reinstallToolSection()
            }
            if shot == "main" {
                self.showMenu()
            } else if let group = MenuGroup.allCases.first(where: { "group:\($0)" == shot }),
                      let submenu = self.menu.items.first(where: { $0.title == group.title })?.submenu {
                // MAXCANDELA_SHOT=group:time (with MAXCANDELA_MENU_LAYOUT=grouped).
                self.tools.forEach { $0.menuWillOpen() }
                submenu.popUp(positioning: nil,
                              at: NSPoint(x: screen.frame.midX, y: screen.frame.maxY - 140), in: nil)
            } else if let tool = self.tools.first(where: { String(describing: type(of: $0)) == shot }),
                      let submenu = tool.menuItem.submenu {
                tool.menuWillOpen()
                submenu.popUp(positioning: nil,
                              at: NSPoint(x: screen.frame.midX, y: screen.frame.maxY - 140), in: nil)
            }
        }
    }
}

/// Keeps the backdrop alive for the life of the process.
private var screenshotBackdropWindow: NSWindow?
#endif
