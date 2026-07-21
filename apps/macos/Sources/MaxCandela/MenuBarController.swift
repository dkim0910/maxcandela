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
    private let menu: NSMenu

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

    /// When the last toggle was applied, so the second click of a double-click
    /// can undo it (see `revertFirstClickToggle`).
    private var lastToggleAppliedAt: Date?
    /// Set when a double-click is detected, so an in-flight entitlement check
    /// doesn't toggle after the user has asked for the menu.
    private var suppressPendingToggle = false

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
        self.menu = NSMenu()

        configureStatusButton()
        buildMenu()
        refresh()
        refreshLicense()
        showWelcomeIfFirstRun()
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

        restoreItem.target = self
        restoreItem.action = #selector(restorePurchases)
        menu.addItem(restoreItem)

        let appStoreItem = NSMenuItem(title: "View in Mac App Store", action: #selector(openAppStore), keyEquivalent: "")
        appStoreItem.target = self
        menu.addItem(appStoreItem)

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
        if let button = statusItem.button {
            let symbol = brightness.isEnabled ? "sun.max.fill" : "sun.min"
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "MaxCandela")
            button.image?.isTemplate = true
        }
        boostItem.title = brightness.isEnabled ? "Turn Boost Off" : "Turn Boost On"
        boostItem.state = brightness.isEnabled ? .on : .off

        if let live = brightness.liveStatus() {
            // On: real live numbers.
            let base = String(format: "Boosting %.2f× (headroom %.2f×)",
                              live.applied, live.headroom)
            switch brightness.thermalStatus {
            case .normal: headroomItem.title = base
            case .eased:  headroomItem.title = base + " · eased for heat"
            case .dimmed: headroomItem.title = String(format: "Dimmed to %.0f%% — Mac too hot",
                                                      live.applied * 100)
            }
        } else if !brightness.canBoost() {
            headroomItem.title = SupportMessages.noHeadroomMenuLine
        } else {
            // Off: the panel's live headroom is ~1.0 until we engage EDR, and
            // the theoretical max overstates reality — so show the real current
            // value if something's already using EDR, else just invite a click.
            let current = brightness.currentHeadroom()
            headroomItem.title = current > 1.05
                ? String(format: "Headroom available now: %.2f×", current)
                : "Click the sun to boost"
        }

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
    }

    /// External license changes (renewal, refund, purchase on another Mac).
    func licenseDidChange() {
        refreshLicense()
    }

    /// Re-check entitlements and localized prices off the main thread.
    private func refreshLicense() {
        Task { @MainActor in
            licenseState = await store.currentState()
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
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
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

    @objc private func restorePurchases() {
        Task { @MainActor in
            await store.restorePurchases()
            refreshLicense()
        }
    }

    /// A tiny invisible window centered on the main screen, used purely as the
    /// anchor for the StoreKit purchase sheet (see StoreManager.purchase).
    private static func makePurchaseAnchor() -> NSWindow? {
        guard let screen = NSScreen.main else { return nil }
        let visible = screen.visibleFrame
        // Base designated init only — the screen: variant traps in subclasses
        // on newer macOS (see CLAUDE.md gotchas); global coordinates instead.
        let window = NSWindow(
            contentRect: NSRect(x: visible.midX - 1, y: visible.midY + 120, width: 2, height: 2),
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
