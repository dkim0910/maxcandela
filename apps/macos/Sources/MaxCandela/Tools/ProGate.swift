import Foundation

/// The one place a tool asks "is MaxCandela Pro available right now?".
///
/// `MenuBarController` owns the licence and is the only writer: it sets
/// `isAllowed` whenever the licence resolves (trial and licensed → true,
/// expired → false) and supplies `requestUpgrade`, which shows the paywall.
/// Tools read `isAllowed`, call `requestUpgrade()` when a Pro action is
/// clicked without it, and observe `onChange` to stand down — a Pro tool that
/// holds something (global shortcuts, hidden menu-bar icons) must let go the
/// moment Pro lapses, the same way the boost does.
///
/// False until the licence check has resolved, for the same reason the boost
/// is not restored from `BrightnessController.init`.
final class ProGate {
    static let shared = ProGate()

    private(set) var isAllowed = false
    var requestUpgrade: () -> Void = {}
    private var observers: [(Bool) -> Void] = []

    func observe(_ observer: @escaping (Bool) -> Void) {
        observers.append(observer)
    }

    func set(allowed: Bool) {
        guard allowed != isAllowed else { return }
        isAllowed = allowed
        observers.forEach { $0(allowed) }
    }

    /// Runs `action` if Pro is available, otherwise shows the paywall.
    func run(_ action: () -> Void) {
        if isAllowed { action() } else { requestUpgrade() }
    }
}
