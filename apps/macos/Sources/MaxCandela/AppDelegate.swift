import AppKit

/// App lifecycle. Owns the two top-level objects — the brightness orchestrator
/// and the menu-bar UI — and keeps them alive for the app's duration.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var brightness: BrightnessController!
    private var menuBar: MenuBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        brightness = BrightnessController()
        menuBar = MenuBarController(brightness: brightness)
        // Keep entitlements fresh (renewals, refunds, purchases on other Macs).
        StoreManager.shared.startTransactionListener { [weak self] in
            self?.menuBar.licenseDidChange()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Quitting must return the display to native brightness. Tear down
        // overlays without clearing the persisted enabled flag, so the app
        // restores the user's state on next launch.
        brightness.shutdown()
    }
}
