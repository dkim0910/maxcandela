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

        configureStatusButton()
        buildMenu()
        refresh()
        refreshLicense()
        startLicenseWatch()
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
            popover.contentViewController = WelcomeViewController(icon: Self.brandIcon) { [weak self] in
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
        boostItem.target = self
        boostItem.action = #selector(toggleBoost)
        menu.addItem(boostItem)

        headroomItem.isEnabled = false
        menu.addItem(headroomItem)

        menu.addItem(.separator())

        licenseItem.isEnabled = false
        menu.addItem(licenseItem)

        lifetimeItem.target = self
        lifetimeItem.action = #selector(buyLifetime)
        menu.addItem(lifetimeItem)

        monthlyItem.target = self
        monthlyItem.action = #selector(buyMonthly)
        // Guideline 3.1.2: the renewal terms must be visible where the
        // subscription is offered.
        monthlyItem.toolTip = "MaxCandela Pro Monthly — auto-renews every month until cancelled in your App Store account settings."
        menu.addItem(monthlyItem)

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
        purchasesMenu.addItem(restoreItem)

        // Redemption previously had no entry point at all — codes worked, but
        // only if the user already knew to go to the App Store app themselves.
        // Hidden once the lifetime unlock is owned (see refresh()).
        redeemItem.target = self
        redeemItem.action = #selector(redeemCode)
        purchasesMenu.addItem(redeemItem)

        let appStoreItem = NSMenuItem(title: "View in Mac App Store", action: #selector(openAppStore), keyEquivalent: "")
        appStoreItem.target = self
        purchasesMenu.addItem(appStoreItem)

        purchasesItem.submenu = purchasesMenu
        menu.addItem(purchasesItem)

        // Single "Legal" item; Terms + Privacy + Support live in its submenu
        // (3.1.2 still satisfied — the links stay reachable from the purchase
        // menu).
        let legalItem = NSMenuItem(title: "Legal", action: nil, keyEquivalent: "")
        let legalMenu = NSMenu()
        let termsItem = NSMenuItem(title: "Terms of Use", action: #selector(openTerms), keyEquivalent: "")
        termsItem.target = self
        legalMenu.addItem(termsItem)
        let privacyItem = NSMenuItem(title: "Privacy Policy", action: #selector(openPrivacy), keyEquivalent: "")
        privacyItem.target = self
        legalMenu.addItem(privacyItem)
        // Separated from the two legal documents — it's a help link, not a
        // policy, and the gap keeps that distinction readable.
        legalMenu.addItem(.separator())
        let supportItem = NSMenuItem(title: "Get Support", action: #selector(openSupport), keyEquivalent: "")
        supportItem.target = self
        legalMenu.addItem(supportItem)
        legalItem.submenu = legalMenu
        menu.addItem(legalItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit MaxCandela",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
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
            licenseItem.title = "Trial ended — unlock to keep boosting"
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

    /// One dimmed row per display, directly under the toggle.
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
                let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
                item.isEnabled = false
                item.indentationLevel = 1
                menu.insertItem(item, at: anchor + 1 + offset)
                perDisplayItems.append(item)
            }
        }

        for (item, status) in zip(perDisplayItems, statuses) {
            item.title = Self.remainingText(status).map { "\(status.name) — \($0)" } ?? status.name
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
            brightness.restorePersistedBoostIfWanted()
        case .expired:
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
                brightness.toggle()
                lastToggleAppliedAt = Date()
            case .expired:
                showPaywallAlert()
            }
            refresh()
        }
    }

    private func showMenu() {
        refreshLicense()
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
        if let url = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        #endif
        // Xcode/App Store build: the asset-catalog app icon is the real thing.
        return NSApp.applicationIconImage
    }()

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
        Keep the full brightness of your display with MaxCandela Pro. One purchase works on all your Macs.

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
                    refresh()
                    Analytics.track("purchase_completed", params: ["product": productID])
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
            refreshLicense()
        }
    }

    /// A tiny invisible window centered on the main screen, used purely as the
    /// anchor for the StoreKit purchase and offer-code sheets.
    private static func makePurchaseAnchor() -> NSWindow? {
        guard let screen = NSScreen.main else { return nil }
        let visible = screen.visibleFrame
        // Base designated init only — the screen: variant traps in subclasses
        // on newer macOS (see CLAUDE.md gotchas); global coordinates instead.
        let window = NSWindow(
            contentRect: NSRect(x: visible.midX - 1, y: visible.midY, width: 2, height: 2),
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

    /// Centre whatever sheet StoreKit attaches to `anchor`.
    ///
    /// A sheet hangs from its parent window's top edge, so a fixed anchor
    /// position only centres a sheet of one particular height — the redeem
    /// sheet and the payment sheet are different sizes, and the anchor used to
    /// carry a constant offset tuned for the latter. Instead, park the anchor
    /// at the screen centre and shift it by the measured error once the sheet
    /// exists; the sheet tracks its parent, so it moves with it.
    ///
    /// The sheet is presented asynchronously by StoreKit (out of process for
    /// the payment sheet), hence the poll rather than a completion hook. It
    /// runs for ~3 s and gives up quietly — a sheet that never arrives just
    /// stays wherever the system put it.
    private static func centerAttachedSheet(on anchor: NSWindow?, attemptsLeft: Int = 150) {
        guard let anchor, attemptsLeft > 0 else { return }
        guard let sheet = anchor.attachedSheet else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                centerAttachedSheet(on: anchor, attemptsLeft: attemptsLeft - 1)
            }
            return
        }
        guard let screen = anchor.screen ?? NSScreen.main else { return }
        let wanted = screen.visibleFrame.midY + sheet.frame.height / 2
        let delta = wanted - sheet.frame.maxY
        guard abs(delta) > 1 else { return }
        var frame = anchor.frame
        frame.origin.y += delta
        anchor.setFrame(frame, display: false)
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
