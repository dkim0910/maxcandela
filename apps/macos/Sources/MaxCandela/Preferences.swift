import Foundation

/// UserDefaults-backed persisted settings: the boost flag and multiplier, the
/// two display adjustments (Extra Dim, Warmth) and the behaviour options.
/// These are *our* preferences only — nothing here is system state, which is
/// what keeps "quit == back to normal" true.
final class Preferences {
    static let shared = Preferences()

    private enum Key {
        static let enabled = "com.maxcandela.enabled"
        static let boost = "com.maxcandela.boost"
        static let extraDim = "com.maxcandela.extraDim"
        static let warmth = "com.maxcandela.warmth"
        static let pauseOnBattery = "com.maxcandela.pauseOnBattery"
        static let hotKey = "com.maxcandela.hotKey"
        static let m5NoticeSeen = "com.maxcandela.m5NoticeSeen"
        static let hotKeyCode = "com.maxcandela.hotKey.keyCode"
        static let hotKeyModifiers = "com.maxcandela.hotKey.modifiers"
        static let hotKeyDisplay = "com.maxcandela.hotKey.display"
        static let warmthScheduled = "com.maxcandela.warmth.scheduled"
        static let warmthStartHour = "com.maxcandela.warmth.startHour"
        static let warmthEndHour = "com.maxcandela.warmth.endHour"
        static let excludedDisplays = "com.maxcandela.excludedDisplays"
        static let boostApps = "com.maxcandela.boostApps"
        static let clickTogglesBoost = "com.maxcandela.clickTogglesBoost"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Register sensible defaults: off, and a neutral 1.0x boost.
        defaults.register(defaults: [
            Key.enabled: false,
            Key.boost: 1.0,
            // 1.0 == no dimming, 0.0 == neutral colour: both off.
            Key.extraDim: 1.0,
            Key.warmth: 0.0,
            // Night window for "Only at Night": 8 PM → 7 AM.
            Key.warmthStartHour: 20,
            Key.warmthEndHour: 7
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

    /// Extra Dim: luminance multiplier below native (1.0 == off). Only takes
    /// effect on a display the boost is not driving.
    var extraDim: Double {
        get { defaults.double(forKey: Key.extraDim) }
        set { defaults.set(newValue, forKey: Key.extraDim) }
    }

    /// Warmth, 0 (neutral) … 1 (warmest).
    var warmth: Double {
        get { defaults.double(forKey: Key.warmth) }
        set { defaults.set(newValue, forKey: Key.warmth) }
    }

    /// Stop boosting while the Mac runs from its battery. Off by default.
    var pauseOnBattery: Bool {
        get { defaults.bool(forKey: Key.pauseOnBattery) }
        set { defaults.set(newValue, forKey: Key.pauseOnBattery) }
    }

    /// Whether the global ⌃⌥⌘B shortcut is registered. Off by default.
    var hotKeyEnabled: Bool {
        get { defaults.bool(forKey: Key.hotKey) }
        set { defaults.set(newValue, forKey: Key.hotKey) }
    }

    /// The one-time M5 Pro / M5 Max notice has been shown (see KnownIssues).
    var m5NoticeSeen: Bool {
        get { defaults.bool(forKey: Key.m5NoticeSeen) }
        set { defaults.set(newValue, forKey: Key.m5NoticeSeen) }
    }

    /// The global shortcut. Falls back to ⌃⌥⌘B until the user records one.
    var shortcut: Shortcut {
        get {
            guard let display = defaults.string(forKey: Key.hotKeyDisplay) else { return .standard }
            return Shortcut(keyCode: UInt32(defaults.integer(forKey: Key.hotKeyCode)),
                            carbonModifiers: UInt32(defaults.integer(forKey: Key.hotKeyModifiers)),
                            display: display)
        }
        set {
            defaults.set(Int(newValue.keyCode), forKey: Key.hotKeyCode)
            defaults.set(Int(newValue.carbonModifiers), forKey: Key.hotKeyModifiers)
            defaults.set(newValue.display, forKey: Key.hotKeyDisplay)
        }
    }

    /// Warmth "Only at Night" and its window (whole hours, 0–23).
    var warmthScheduled: Bool {
        get { defaults.bool(forKey: Key.warmthScheduled) }
        set { defaults.set(newValue, forKey: Key.warmthScheduled) }
    }

    var warmthStartHour: Int {
        get { defaults.integer(forKey: Key.warmthStartHour) }
        set { defaults.set(newValue, forKey: Key.warmthStartHour) }
    }

    var warmthEndHour: Int {
        get { defaults.integer(forKey: Key.warmthEndHour) }
        set { defaults.set(newValue, forKey: Key.warmthEndHour) }
    }

    /// Displays the user has taken out of the boost, by `DisplayInfo.stableID`.
    var excludedDisplays: Set<String> {
        get { Set(defaults.stringArray(forKey: Key.excludedDisplays) ?? []) }
        set { defaults.set(Array(newValue).sorted(), forKey: Key.excludedDisplays) }
    }

    /// What a single click on the status icon does: toggle the boost (the
    /// original behaviour) or open the menu (the toolbox default). Nil until
    /// decided — see `MenuBarController.resolveClickBehaviour`.
    var clickTogglesBoost: Bool? {
        get { defaults.object(forKey: Key.clickTogglesBoost) as? Bool }
        set { defaults.set(newValue, forKey: Key.clickTogglesBoost) }
    }

    /// "Boost Only In": bundle identifier → display name. Empty == every app.
    var boostApps: [String: String] {
        get { defaults.dictionary(forKey: Key.boostApps) as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: Key.boostApps) }
    }
}
