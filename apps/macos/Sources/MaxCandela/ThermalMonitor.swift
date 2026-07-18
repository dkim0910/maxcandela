import Foundation

/// Watches the system thermal state and reports how much of the brightness
/// boost is safe to apply. The boost is a heat source, so when the Mac runs
/// hot the app eases the *extra* brightness down (we can't touch fans — that
/// needs SMC access a sandboxed App Store app can't have; see CLAUDE.md).
final class ThermalMonitor {
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

    /// Fraction of the boost-above-native that's currently allowed (0…1).
    var ceiling: CGFloat {
        #if DEBUG
        // Force a thermal state for testing: MAXCANDELA_FORCE_THERMAL=serious
        // (or fair/critical/nominal). Real thermal state can't be triggered on
        // demand via public API.
        if let forced = ProcessInfo.processInfo.environment["MAXCANDELA_FORCE_THERMAL"] {
            switch forced {
            case "nominal": return 1.0
            case "fair": return 1.0
            case "serious": return 0.5
            case "critical": return 0.0
            default: break
            }
        }
        #endif
        return Self.ceiling(for: ProcessInfo.processInfo.thermalState)
    }

    /// Pure mapping, split out for unit testing. `.fair` is normal under load,
    /// so it stays at full; back-off begins at `.serious`.
    static func ceiling(for state: ProcessInfo.ThermalState) -> CGFloat {
        switch state {
        case .nominal: return 1.0
        case .fair:    return 1.0
        case .serious: return 0.5
        case .critical: return 0.0
        @unknown default: return 0.5
        }
    }

    @objc private func thermalStateChanged() {
        onChange?()
    }
}
