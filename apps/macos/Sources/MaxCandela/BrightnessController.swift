import AppKit

/// Orchestrator. Owns one `EDROverlayWindow` per active screen, applies the
/// clamped boost to each, and reacts to screen-configuration changes.
///
/// Invariants (see CLAUDE.md):
///  - The live boost is always clamped to each display's *current* EDR headroom.
///  - Disabling tears down every overlay so the display returns to native
///    brightness immediately. No persistent system state is touched.
final class BrightnessController {
    private let displayManager = DisplayManager()
    private let prefs = Preferences.shared
    private var overlays: [CGDirectDisplayID: EDROverlayWindow] = [:]

    /// The user-requested boost multiplier (unclamped). 1.0 == native.
    private(set) var requestedBoost: CGFloat

    init() {
        self.requestedBoost = CGFloat(prefs.boost)
        displayManager.onScreenConfigurationChanged = { [weak self] in
            self?.rebuildOverlays()
        }
        if prefs.isEnabled {
            enable()
        }
    }

    // MARK: - Public control surface

    var isEnabled: Bool { prefs.isEnabled }

    func enable() {
        prefs.isEnabled = true
        rebuildOverlays()
    }

    func disable() {
        prefs.isEnabled = false
        teardownOverlays()
    }

    func toggle() {
        isEnabled ? disable() : enable()
    }

    /// Tear down overlays without touching the persisted enabled flag — used on
    /// app termination so the display returns to native brightness but the
    /// enabled preference survives to the next launch.
    func shutdown() {
        teardownOverlays()
    }

    /// Set the requested boost (from the menu slider). Persists and re-applies.
    func setBoost(_ value: CGFloat) {
        requestedBoost = value
        prefs.boost = Double(value)
        applyBoost()
    }

    /// Best potential headroom across displays, for UI copy ("up to N×").
    func maxPotentialBoost() -> CGFloat {
        displayManager.bestPotentialHeadroom()
    }

    // MARK: - Overlay lifecycle

    private func rebuildOverlays() {
        teardownOverlays()
        guard prefs.isEnabled else { return }

        for info in displayManager.currentDisplays() where info.supportsBoost {
            guard let overlay = EDROverlayWindow(screen: info.screen) else {
                NSLog("MaxCandela: Metal unavailable; cannot create overlay for display \(info.displayID)")
                continue
            }
            overlays[info.displayID] = overlay
            overlay.activate()
        }
        applyBoost()
    }

    private func teardownOverlays() {
        for overlay in overlays.values {
            overlay.deactivate()
        }
        overlays.removeAll()
    }

    /// Push the clamped boost to each overlay. Clamped per-display against that
    /// display's *current* headroom — never above what the OS allows right now.
    private func applyBoost() {
        for info in displayManager.currentDisplays() {
            guard let overlay = overlays[info.displayID] else { continue }
            let ceiling = max(1.0, info.currentHeadroom)
            overlay.renderer.boost = min(requestedBoost, ceiling)
        }
    }
}
