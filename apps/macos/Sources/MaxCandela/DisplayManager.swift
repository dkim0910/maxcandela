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

    /// Screen-parameter notifications fire in bursts — notably when *our own*
    /// EDR trigger flips the display into HDR mode. Debounce so a burst
    /// becomes one callback instead of a flickering rebuild loop.
    private var debounceTimer: Timer?

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        debounceTimer?.invalidate()
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

    /// The best potential headroom across all displays — the panel's theoretical
    /// ceiling. Use only to decide whether a display *can* boost at all, not as
    /// a realistic number to show the user (it overstates what's achievable).
    func bestPotentialHeadroom() -> CGFloat {
        currentDisplays().map(\.potentialHeadroom).max() ?? 1.0
    }

    /// The best *live* headroom across displays right now — the real, achievable
    /// value. ~1.0 until EDR is engaged, then ramps to what the panel sustains.
    func bestCurrentHeadroom() -> CGFloat {
        currentDisplays().map(\.currentHeadroom).max() ?? 1.0
    }

    @objc private func screenParametersChanged() {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.onScreenConfigurationChanged?()
        }
    }
}
