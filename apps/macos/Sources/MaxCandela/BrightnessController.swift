import AppKit

/// Orchestrator. Owns one tiny EDR trigger window per boost-capable screen,
/// polls the live EDR headroom, and applies the gamma lift that actually
/// brightens the whole screen (see CLAUDE.md: EDR alone gets compensated away;
/// trigger + lift together do the job).
///
/// Gamma changes are never applied as hard steps — every change fades through
/// a 30 Hz animator (hard table swaps read as screen flicker). Likewise,
/// screen-reconfiguration events only rebuild windows when the display set
/// actually changed; a restore/re-apply cycle on every notification flashes.
///
/// Invariants (see CLAUDE.md):
///  - The live lift is always clamped to each display's *current* EDR headroom,
///    re-checked every poll tick — thermal/battery ceilings are followed down.
///  - Disabling tears down triggers and restores gamma so the display returns
///    to native brightness. CG gamma also auto-restores if the process dies.
final class BrightnessController {
    /// How the live target is computed from what the user asked for and what
    /// the OS currently allows. Pure, unit-tested.
    static func targetScale(requested: CGFloat, currentHeadroom: CGFloat) -> CGFloat {
        max(1.0, min(requested, currentHeadroom))
    }

    /// One animator frame: move `current` toward `target` by `rate` of the
    /// remaining distance, snapping when close. Pure, unit-tested.
    static func animationStep(current: CGFloat, target: CGFloat,
                              rate: CGFloat = 0.3, snapWithin: CGFloat = 0.01) -> CGFloat {
        let next = current + (target - current) * rate
        return abs(next - target) < snapWithin ? target : next
    }

    private let displayManager = DisplayManager()
    private let gamma = GammaController()
    private let prefs = Preferences.shared
    private var overlays: [CGDirectDisplayID: EDROverlayWindow] = [:]

    /// What's on the glass right now vs. where the fade is heading.
    private var currentScales: [CGDirectDisplayID: CGFloat] = [:]
    private var targetScales: [CGDirectDisplayID: CGFloat] = [:]

    private var pollTimer: Timer?
    private var animationTimer: Timer?

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
        stopTimers()
        teardownAllOverlays()
    }

    func toggle() {
        isEnabled ? disable() : enable()
    }

    /// Tear down without touching the persisted enabled flag — used on app
    /// termination so the user's state survives to the next launch.
    func shutdown() {
        stopTimers()
        teardownAllOverlays()
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
        let applied = currentScales[best.displayID] ?? 1.0
        return (applied, best.currentHeadroom)
    }

    // MARK: - Poll loop

    /// EDR headroom ramps up over a few seconds after the trigger appears and
    /// drifts with thermals/battery — poll it and follow (never cache).
    private func startPolling() {
        pollTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshTargets()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
        refreshTargets()
    }

    private func stopTimers() {
        pollTimer?.invalidate()
        pollTimer = nil
        animationTimer?.invalidate()
        animationTimer = nil
    }

    // MARK: - Overlay lifecycle

    /// Create/remove trigger windows only when the boost-capable display set
    /// actually changed. EDR engagement fires screen notifications; treating
    /// those as full rebuilds caused a restore/re-apply flicker loop.
    private func rebuildOverlays() {
        guard prefs.isEnabled else { return }

        let wanted = Set(
            displayManager.currentDisplays()
                .filter(\.supportsBoost)
                .map(\.displayID)
        )
        let existing = Set(overlays.keys)
        guard wanted != existing else {
            refreshTargets()
            return
        }

        // Remove triggers for departed displays (no gamma restore needed —
        // restore is global and would flash the surviving displays).
        for id in existing.subtracting(wanted) {
            overlays[id]?.deactivate()
            overlays[id] = nil
            currentScales[id] = nil
            targetScales[id] = nil
        }

        // Add triggers for new displays.
        // uniquingKeysWith: mirrored screens can report duplicate display IDs;
        // uniqueKeysWithValues would trap on that.
        let infoByID = Dictionary(displayManager.currentDisplays().map { ($0.displayID, $0) },
                                  uniquingKeysWith: { first, _ in first })
        for id in wanted.subtracting(existing) {
            guard let info = infoByID[id] else { continue }
            guard let overlay = EDROverlayWindow(screen: info.screen) else {
                NSLog("MaxCandela: Metal unavailable; cannot create trigger for display \(id)")
                continue
            }
            overlays[id] = overlay
            overlay.activate()
        }
        refreshTargets()
    }

    private func teardownAllOverlays() {
        for overlay in overlays.values {
            overlay.deactivate()
        }
        overlays.removeAll()
        targetScales.removeAll()
        if !currentScales.isEmpty {
            currentScales.removeAll()
            gamma.restoreAll()
        }
    }

    // MARK: - Target computation + fade

    /// Recompute per-display targets from the live headroom and kick the
    /// animator if anything needs to move.
    private func refreshTargets() {
        var needsAnimation = false
        for info in displayManager.currentDisplays() {
            guard let overlay = overlays[info.displayID] else { continue }

            // Keep the trigger patch at the headroom ceiling so the compositor
            // holds EDR mode fully open.
            overlay.renderer.boost = max(1.0, info.currentHeadroom)

            let target = Self.targetScale(requested: requestedBoost,
                                          currentHeadroom: info.currentHeadroom)
            if targetScales[info.displayID] != target {
                targetScales[info.displayID] = target
                NSLog("MaxCandela: display %u headroom %.2f× → fading lift to %.2f× (requested %.2f×)",
                      info.displayID, info.currentHeadroom, target, requestedBoost)
            }
            if abs((currentScales[info.displayID] ?? 1.0) - target) > 0.001 {
                needsAnimation = true
            }
        }
        if needsAnimation {
            startAnimatorIfNeeded()
        }
    }

    /// 30 Hz fade toward the targets; stops itself when everything has snapped.
    private func startAnimatorIfNeeded() {
        guard animationTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.animationTick()
        }
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    private func animationTick() {
        var allSettled = true
        for (id, target) in targetScales {
            let current = currentScales[id] ?? 1.0
            guard abs(current - target) > 0.001 else { continue }

            let next = Self.animationStep(current: current, target: target)
            if gamma.applyLift(scale: next, to: id) {
                // Only record progress the display actually accepted — otherwise
                // liveStatus() would report a boost that isn't on the glass.
                currentScales[id] = next
                if next != target {
                    allSettled = false
                }
            } else {
                // Display refused the lift: stop chasing it this fade instead
                // of spinning the animator forever. The next poll retries.
                targetScales[id] = current
            }
        }
        if allSettled {
            animationTimer?.invalidate()
            animationTimer = nil
        }
    }
}
