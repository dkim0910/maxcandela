import Foundation

/// UserDefaults-backed persisted settings: whether boosting is enabled and the
/// last boost multiplier the user selected. Kept intentionally tiny — no other
/// persistent state exists, which is what makes "quit == back to normal" true.
final class Preferences {
    static let shared = Preferences()

    private enum Key {
        static let enabled = "com.maxcandela.enabled"
        static let boost = "com.maxcandela.boost"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Register sensible defaults: off, and a neutral 1.0x boost.
        defaults.register(defaults: [
            Key.enabled: false,
            Key.boost: 1.0
        ])
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Key.enabled) }
        set { defaults.set(newValue, forKey: Key.enabled) }
    }

    /// User-selected boost multiplier (1.0 == native brightness). This is the
    /// *requested* value; the live output is always clamped to the display's
    /// current EDR headroom by BrightnessController.
    var boost: Double {
        get { defaults.double(forKey: Key.boost) }
        set { defaults.set(newValue, forKey: Key.boost) }
    }
}
