import AppKit

/// Orchestrator. Owns one tiny EDR trigger window per boost-capable screen,
/// polls the live EDR headroom, and applies the gamma lift that actually
/// brightens the whole screen (see CLAUDE.md: EDR alone gets compensated away;
/// trigger + lift together do the job).
///
/// Invariants (see CLAUDE.md):
///  - The live lift is always clamped to each display's *current* EDR headroom,
///    re-checked every poll tick — thermal/battery ceilings are followed down.
///  - Disabling tears down triggers and restores gamma so the display returns
///    to native brightness immediately. CG gamma also auto-restores if the
///    process dies, so no failure mode leaves the screen stuck.
final class BrightnessController {
    /// How the live target is computed from what the user asked for and what
    /// the OS currently allows. Pure, unit-tested.
    static func targetScale(requested: CGFloat, currentHeadroom: CGFloat) -> CGFloat {
        max(1.0, min(requested, currentHeadroom))
    }

    /// Headroom changes smaller than this don't trigger a gamma re-apply.
    private static let reapplyThreshold: CGFloat = 0.05

    private let displayManager = DisplayManager()
    private let gamma = GammaController()
    private let prefs = Preferences.shared
    private var overlays: [CGDirectDisplayID: EDROverlayWindow] = [:]
    private var appliedScales: [CGDirectDisplayID: CGFloat] = [:]
    private var pollTimer: Timer?

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

    /// Toggle-on means "full brightness": target the best the panel can do and
    /// let the poll loop hold it there (tracking thermal ceilings). The slider
    /// can still fine-tune below max afterwards via setBoost.
    func enable() {
        prefs.isEnabled = true
        requestedBoost = max(requestedBoost, displayManager.bestPotentialHeadroom())
        prefs.boost = Double(requestedBoost)
        rebuildOverlays()
        startPolling()
    }

    func disable() {
        prefs.isEnabled = false
        stopPolling()
        teardownOverlays()
    }

    func toggle() {
        isEnabled ? disable() : enable()
    }

    /// Tear down without touching the persisted enabled flag — used on app
    /// termination so the user's state survives to the next launch.
    func shutdown() {
        stopPolling()
        teardownOverlays()
    }

    /// Set the requested boost (from the menu slider). Persists and applies
    /// immediately.
    func setBoost(_ value: CGFloat) {
        requestedBoost = value
        prefs.boost = Double(value)
        applyBoost(force: true)
    }

    /// Best potential headroom across displays, for UI copy ("up to N×").
    func maxPotentialBoost() -> CGFloat {
        displayManager.bestPotentialHeadroom()
    }

    /// Live info for the menu: (applied lift, current headroom) of the display
    /// with the most headroom, or nil when disabled/no data yet.
    func liveStatus() -> (applied: CGFloat, headroom: CGFloat)? {
        guard isEnabled,
              let best = displayManager.currentDisplays()
                  .max(by: { $0.currentHeadroom < $1.currentHeadroom })
        else { return nil }
        let applied = appliedScales[best.displayID] ?? 1.0
        return (applied, best.currentHeadroom)
    }

    // MARK: - Poll loop

    /// EDR headroom ramps up over a few seconds after the trigger appears and
    /// drifts with thermals/battery — poll it and follow (never cache).
    private func startPolling() {
        stopPolling()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.applyBoost(force: false)
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
        applyBoost(force: true)
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: - Overlay lifecycle

    private func rebuildOverlays() {
        teardownOverlays()
        guard prefs.isEnabled else { return }

        for info in displayManager.currentDisplays() where info.supportsBoost {
            guard let overlay = EDROverlayWindow(screen: info.screen) else {
                NSLog("MaxCandela: Metal unavailable; cannot create trigger for display \(info.displayID)")
                continue
            }
            overlays[info.displayID] = overlay
            overlay.activate()
        }
        applyBoost(force: true)
    }

    private func teardownOverlays() {
        for overlay in overlays.values {
            overlay.deactivate()
        }
        overlays.removeAll()
        if !appliedScales.isEmpty {
            appliedScales.removeAll()
            gamma.restoreAll()
        }
    }

    /// One tick: for each triggered display, compute the clamped target and
    /// (re-)apply the renderer boost + gamma lift when it moved enough.
    private func applyBoost(force: Bool) {
        for info in displayManager.currentDisplays() {
            guard let overlay = overlays[info.displayID] else { continue }

            let target = Self.targetScale(requested: requestedBoost,
                                          currentHeadroom: info.currentHeadroom)
            // Keep the trigger patch at the headroom ceiling so the compositor
            // holds EDR mode fully open.
            overlay.renderer.boost = max(1.0, info.currentHeadroom)

            let applied = appliedScales[info.displayID]
            if force || applied == nil || abs((applied ?? 1.0) - target) > Self.reapplyThreshold {
                if gamma.applyLift(scale: target, to: info.displayID) {
                    appliedScales[info.displayID] = target
                }
                NSLog("MaxCandela: display %u headroom %.2f× → lift %.2f× (requested %.2f×)",
                      info.displayID, info.currentHeadroom, target, requestedBoost)
            }
        }
    }
}
