import AppKit
import StoreKit

/// The menu-bar surface. Left-clicking the ☀️ status icon toggles the boost
/// instantly (license permitting); right-clicking opens a menu with headroom
/// info, license status/purchases, and Quit.
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let brightness: BrightnessController
    private let store = StoreManager.shared
    private let headroomItem: NSMenuItem
    private let licenseItem: NSMenuItem
    private let lifetimeItem: NSMenuItem
    private let monthlyItem: NSMenuItem
    private let restoreItem: NSMenuItem
    private let menu: NSMenu

    /// Held so the first-run welcome popover isn't deallocated while shown.
    private var welcomePopover: NSPopover?
    private static let welcomeSeenKey = "com.maxcandela.hasSeenWelcome"

    /// Last observed license state; refreshed on launch and every menu open.
    private var licenseState: StoreManager.LicenseState = .trial(daysRemaining: StoreManager.shared.trialDaysRemaining)

    init(brightness: BrightnessController) {
        self.brightness = brightness
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
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
        // Receive both left and right clicks so we can toggle vs. show menu.
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func buildMenu() {
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
        menu.addItem(monthlyItem)

        restoreItem.target = self
        restoreItem.action = #selector(restorePurchases)
        menu.addItem(restoreItem)

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
            headroomItem.title = "No EDR headroom on this display"
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
            [lifetimeItem, monthlyItem, restoreItem].forEach { $0.isHidden = true }
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
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu()
            return
        }

        // Turning OFF is always allowed — the kill switch never sits behind
        // the paywall. Turning ON requires a valid trial or license.
        if brightness.isEnabled {
            brightness.toggle()
            refresh()
            return
        }
        Task { @MainActor in
            licenseState = await store.currentState()
            switch licenseState {
            case .licensed, .trial:
                brightness.toggle()
            case .expired:
                showPaywallAlert()
            }
            refresh()
        }
    }

    private func showMenu() {
        refreshLicense()
        refresh()
        // Assign the menu just long enough to pop it up, then detach so plain
        // left-clicks keep reaching statusButtonClicked (an attached menu
        // hijacks all clicks on the status item).
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    /// The MaxCandela logo for dialogs. Loaded from the bundled resource so it
    /// shows even under `swift run` (a bare binary otherwise has no app icon,
    /// so NSAlert falls back to a generic file/document icon). Falls back to the
    /// app icon in a normal bundled launch.
    private static let brandIcon: NSImage? = {
        if let url = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return NSApp.applicationIconImage
    }()

    private func showPaywallAlert() {
        Analytics.track("paywall_shown")
        let alert = NSAlert()
        alert.icon = Self.brandIcon
        alert.messageText = "Your free trial has ended"
        alert.informativeText = "Keep the full brightness of your display with MaxCandela Pro: $9.99 once, or $0.99/month. One purchase works on all your Macs."
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

    @objc private func buyLifetime() { purchase(productID: StoreManager.lifetimeProductID) }
    @objc private func buyMonthly() { purchase(productID: StoreManager.monthlyProductID) }

    private func purchase(productID: String) {
        Task { @MainActor in
            await store.loadProducts()
            guard let product = store.product(id: productID) else {
                showStoreUnavailableAlert()
                return
            }
            do {
                if try await store.purchase(product) {
                    licenseState = .licensed
                    refresh()
                    Analytics.track("purchase_completed", params: ["product": productID])
                }
            } catch {
                NSLog("MaxCandela: purchase failed: \(error.localizedDescription)")
            }
        }
    }

    @objc private func restorePurchases() {
        Task { @MainActor in
            await store.restorePurchases()
            refreshLicense()
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
