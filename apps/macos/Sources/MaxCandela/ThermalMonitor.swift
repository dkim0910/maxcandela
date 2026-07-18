import Foundation

/// Watches the system thermal state and reports how the brightness should be
/// limited to protect the Mac. The boost is a heat source, so as the Mac heats
/// up the app first eases the *extra* brightness down, then — when critically
/// hot — actively **dims below normal** to shed heat (we can't touch fans; that
/// needs SMC access a sandboxed App Store app can't have, see CLAUDE.md).
final class ThermalMonitor {
    /// Thermal limits for the current state.
    struct Limits: Equatable {
        /// Fraction of the boost-above-native still allowed (0…1).
        let boostCeiling: CGFloat
        /// If set, actively dim the whole display to this multiplier of normal
        /// (< 1.0) for safety. `nil` means "don't dim below normal".
        let dimTo: CGFloat?
    }

    /// How dark the safety dim goes when the Mac is critically hot. 0.8 = 80%
    /// of normal brightness — noticeable but not jarring, enough to cut
    /// backlight power/heat.
    static let criticalDim: CGFloat = 0.8

    /// Called on every thermal-state transition so the controller can
    /// re-evaluate immediately instead of waiting for its 1 s poll.
    var onChange: (() -> Void)?

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateChanged),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Current thermal limits (honors the DEBUG force-override).
    var limits: Limits {
        #if DEBUG
        // Force a thermal state for testing: MAXCANDELA_FORCE_THERMAL=serious
        // (or fair/critical/nominal). Real thermal state can't be triggered on
        // demand via public API.
        if let forced = ProcessInfo.processInfo.environment["MAXCANDELA_FORCE_THERMAL"] {
            switch forced {
            case "nominal": return Self.limits(for: .nominal)
            case "fair": return Self.limits(for: .fair)
            case "serious": return Self.limits(for: .serious)
            case "critical": return Self.limits(for: .critical)
            default: break
            }
        }
        #endif
        return Self.limits(for: ProcessInfo.processInfo.thermalState)
    }

    /// Pure mapping, split out for unit testing.
    ///  - nominal / fair: full boost, no dim (fair is normal under load).
    ///  - serious: half the extra boost, no dim.
    ///  - critical: no boost AND a safety dim below normal.
    static func limits(for state: ProcessInfo.ThermalState) -> Limits {
        switch state {
        case .nominal, .fair:
            return Limits(boostCeiling: 1.0, dimTo: nil)
        case .serious:
            return Limits(boostCeiling: 0.5, dimTo: nil)
        case .critical:
            return Limits(boostCeiling: 0.0, dimTo: criticalDim)
        @unknown default:
            return Limits(boostCeiling: 0.5, dimTo: nil)
        }
    }

    @objc private func thermalStateChanged() {
        onChange?()
    }
}
