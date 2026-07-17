import AppKit

/// A snapshot of one display's EDR capability. Note that `currentHeadroom` is a
/// live, changing value (ambient light, thermal, battery) — always re-read it,
/// never cache it. See CLAUDE.md.
struct DisplayInfo {
    let screen: NSScreen
    let currentHeadroom: CGFloat        // maximumExtendedDynamicRangeColorComponentValue
    let potentialHeadroom: CGFloat      // maximumPotential…ColorComponentValue

    /// A display can only be boosted if it has headroom above SDR white (1.0).
    var supportsBoost: Bool { potentialHeadroom > 1.0 }

    var displayID: CGDirectDisplayID {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) ?? 0
    }
}

/// Enumerates attached displays, reports their EDR capability, and notifies when
/// the screen configuration changes (connect/disconnect/resolution).
final class DisplayManager {
    /// Called whenever the set of screens or their arrangement changes.
    var onScreenConfigurationChanged: (() -> Void)?

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Current info for every attached screen.
    func currentDisplays() -> [DisplayInfo] {
        NSScreen.screens.map { screen in
            DisplayInfo(
                screen: screen,
                currentHeadroom: screen.maximumExtendedDynamicRangeColorComponentValue,
                potentialHeadroom: screen.maximumPotentialExtendedDynamicRangeColorComponentValue
            )
        }
    }

    /// The best potential headroom across all displays — used for UI copy like
    /// "up to N×". Returns 1.0 (no boost available) if nothing supports EDR.
    func bestPotentialHeadroom() -> CGFloat {
        currentDisplays().map(\.potentialHeadroom).max() ?? 1.0
    }

    @objc private func screenParametersChanged() {
        onScreenConfigurationChanged?()
    }
}
