import AppKit

/// App lifecycle. Owns the two top-level objects — the brightness orchestrator
/// and the menu-bar UI — and keeps them alive for the app's duration.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var brightness: BrightnessController!
    private var menuBar: MenuBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Invisible in an accessory app, but it is what makes ⌘X/⌘C/⌘V work in
        // the text fields we present (redeem sheet, paywall). See AppMenu.
        AppMenu.install(on: NSApplication.shared)
        // Before MenuBarController: its init resolves the licence, which
        // mirrors the state to RevenueCat, and purchases must be recordable
        // from the first menu open.
        ConversionTracker.configure()
        brightness = BrightnessController()
        menuBar = MenuBarController(brightness: brightness)
        // Shortcuts actions and maxcandela:// links queue until this exists.
        BoostAutomation.install { [weak self] command in
            guard let menuBar = self?.menuBar else { return .off }
            return await menuBar.setBoostFromAutomation(command)
        }
        Analytics.track("app_launch")
        // Keep entitlements fresh (renewals, refunds, purchases on other Macs).
        StoreManager.shared.startTransactionListener { [weak self] in
            self?.menuBar.licenseDidChange()
        }
    }

    /// `maxcandela://boost/on|off|toggle` — for Raycast, Alfred, BetterTouchTool
    /// and anything else that can open a URL. Unknown links are ignored.
    /// Can arrive before `applicationDidFinishLaunching` when the link is what
    /// launched the app; `BoostAutomation` holds it until the menu exists.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard let command = BoostCommand(url: url) else {
                NSLog("MaxCandela: ignoring unrecognised link \(url.absoluteString)")
                continue
            }
            #if DEBUG
            // Separates "macOS delivered the link late" from "we were slow".
            NSLog("MaxCandela: link received \(command)")
            #endif
            BoostAutomation.enqueue(command)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Quitting must return the display to native brightness. Tear down
        // overlays without clearing the persisted enabled flag, so the app
        // restores the user's state on next launch.
        brightness.shutdown()
        menuBar.shutdown()
    }
}
