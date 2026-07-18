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
        let potential = brightness.maxPotentialBoost()
        if let live = brightness.liveStatus() {
            headroomItem.title = String(format: "Boosting %.2f× (headroom %.2f×)",
                                        live.applied, live.headroom)
        } else if potential > 1.0 {
            headroomItem.title = String(format: "Headroom: up to %.1f×", potential)
        } else {
            headroomItem.title = "No EDR headroom on this display"
        }

        switch licenseState {
        case .licensed:
            licenseItem.title = "MaxCandela Pro — unlocked"
            [lifetimeItem, monthlyItem, restoreItem].forEach { $0.isHidden = true }
        case .trial(let days):
            licenseItem.title = "Free trial — \(days) day\(days == 1 ? "" : "s") left"
            [lifetimeItem, monthlyItem, restoreItem].forEach { $0.isHidden = false }
        case .expired:
            licenseItem.title = "Trial ended — unlock to keep boosting"
            [lifetimeItem, monthlyItem, restoreItem].forEach { $0.isHidden = false }
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

    private func showPaywallAlert() {
        let alert = NSAlert()
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
        alert.messageText = "App Store unavailable"
        alert.informativeText = "Products could not be loaded. Check your internet connection and try again."
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
