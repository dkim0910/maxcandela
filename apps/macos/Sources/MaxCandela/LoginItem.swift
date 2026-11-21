import Foundation
import ServiceManagement

/// "Launch at Login" via `SMAppService.mainApp` — the public, sandbox-safe
/// login-item API (macOS 13+). No helper bundle, no entitlement.
///
/// The system is the source of truth, not UserDefaults: the user can remove
/// the app under System Settings ▸ General ▸ Login Items at any time, and a
/// cached flag would then lie. Off until the user turns it on (Guideline
/// 2.4.5(iii): never auto-launch without consent).
///
/// A bare `swift run` binary is not a bundle, so `register()` throws there —
/// test this in `dist/MaxCandela.app` or the Xcode build.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Throws the system's error so the caller can show it — a silent failure
    /// would leave a checkbox that never sticks.
    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
