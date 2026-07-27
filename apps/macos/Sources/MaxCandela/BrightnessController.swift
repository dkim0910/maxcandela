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
    /// How the live target is computed from what the user asked for, what the
    /// OS currently allows, and the thermal limits. Pure, unit-tested.
    ///
    /// The thermal `boostCeiling` scales only the boost *above* native (1.0): a
    /// ceiling of 0.5 halves the extra brightness, 0.0 removes it (native).
    /// `dimTo`, when set (critical heat), caps the result below native — an
    /// active safety dim (e.g. 0.8 = 80% brightness).
    static func targetScale(requested: CGFloat, currentHeadroom: CGFloat,
                            thermalCeiling: CGFloat = 1.0,
                            dimTo: CGFloat? = nil) -> CGFloat {
        let clamped = min(requested, currentHeadroom)
        let extra = max(0, clamped - 1.0)
        let boostTarget = max(1.0, 1.0 + extra * max(0, min(1, thermalCeiling)))
        // A safety dim caps below native; otherwise the boost target stands.
        if let dimTo {
            return min(boostTarget, dimTo)
        }
        return boostTarget
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
    private let thermal = ThermalMonitor()
    private let prefs = Preferences.shared
    private var overlays: [CGDirectDisplayID: EDROverlayWindow] = [:]

    /// What's on the glass right now vs. where the fade is heading.
    private var currentScales: [CGDirectDisplayID: CGFloat] = [:]
    private var targetScales: [CGDirectDisplayID: CGFloat] = [:]

    private var pollTimer: Timer?
    private var animationTimer: Timer?

    /// Set when the heat guard has cut the boost. The EDR triggers stay up
    /// until the gamma fade has landed and come back down only once the Mac has
    /// cooled — the boost stays "on" from the user's point of view throughout,
    /// so `prefs.isEnabled` is deliberately untouched.
    private var heatSuspended = false

    /// The user-requested boost multiplier (unclamped). 1.0 == native.
    private(set) var requestedBoost: CGFloat

    init() {
        self.requestedBoost = CGFloat(prefs.boost)
        displayManager.onScreenConfigurationChanged = { [weak self] in
            self?.rebuildOverlays()
        }
        // React the instant the Mac heats up or cools, not just on the 1 s poll.
        thermal.onChange = { [weak self] in
            self?.refreshTargets()
        }
        // Deliberately does NOT restore the persisted boost here. Doing so was a
        // full paywall bypass: the entitlement check lives in MenuBarController
        // and is async, so a boost left on simply came back at every launch and
        // an expired trial never stopped anything. The restore now runs through
        // `restorePersistedBoostIfWanted()` once the licence has been checked.
    }

    // MARK: - Public control surface

    /// Whether the boost is actually running right now. Distinct from the
    /// persisted flag below: between launch and the licence check resolving,
    /// the user's saved "on" is an intent that hasn't been honoured yet.
    private(set) var isEnabled = false

    /// The user's saved preference — what they left the boost set to.
    var wantsPersistedBoost: Bool { prefs.isEnabled }

    /// Toggle-on means "full brightness": target the best the panel can do and
    /// let the poll loop hold it there (tracking thermal ceilings). The slider
    /// can still fine-tune below max afterwards via setBoost.
    func enable() {
        prefs.isEnabled = true
        isEnabled = true
        // A fresh switch-on re-arms the heat guard: it re-evaluates on the very
        // first poll, so a still-hot Mac drops straight back to protecting.
        heatSuspended = false
        // Time spent switched off is time the panel spent cooling.
        thermal.creditIdleCooling()
        requestedBoost = max(requestedBoost, displayManager.bestPotentialHeadroom())
        prefs.boost = Double(requestedBoost)
        rebuildOverlays()
        startPolling()
    }

    func disable() {
        prefs.isEnabled = false
        isEnabled = false
        heatSuspended = false
        stopTimers()
        teardownAllOverlays()
    }

    /// Restore the boost the user left on last session. Split out of `init` so
    /// it can run *after* the licence check — see the note there.
    func restorePersistedBoostIfWanted() {
        guard prefs.isEnabled, !isEnabled else { return }
        enable()
    }

    /// Stop boosting because the licence no longer allows it, *without*
    /// discarding the user's saved preference — buying or restoring should
    /// bring their setting straight back rather than making them re-toggle.
    func suspendForLicense() {
        guard isEnabled else { return }
        isEnabled = false
        heatSuspended = false
        stopTimers()
        teardownAllOverlays()
    }

    func toggle() {
        if isEnabled {
            disable()
            Analytics.track("boost_disabled")
        } else {
            enable()
            Analytics.track("boost_enabled")
        }
    }

    /// Tear down without touching the persisted enabled flag — used on app
    /// termination so the user's state survives to the next launch.
    func shutdown() {
        isEnabled = false
        stopTimers()
        teardownAllOverlays()
    }

    /// Whether any attached display can be boosted at all.
    func canBoost() -> Bool {
        #if DEBUG
        // MAXCANDELA_FORCE_NO_HEADROOM=1 pretends every display is a MacBook
        // Air, so the "no boost available" path can be reviewed on an XDR Mac.
        if ProcessInfo.processInfo.environment["MAXCANDELA_FORCE_NO_HEADROOM"] == "1" {
            return false
        }
        #endif
        return displayManager.bestPotentialHeadroom() > 1.0
    }

    /// The real, live headroom across displays right now (not the theoretical
    /// potential). ~1.0 when nothing has engaged EDR.
    func currentHeadroom() -> CGFloat {
        displayManager.bestCurrentHeadroom()
    }

    /// How heat is currently affecting brightness, for the menu to explain a
    /// reduced, paused or dimmed screen.
    enum ThermalStatus { case normal, eased, paused, dimmed }
    var thermalStatus: ThermalStatus {
        guard isEnabled else { return .normal }
        switch thermal.stage {
        case .normal: return .normal
        case .eased: return .eased
        // Only the OS's own critical state dims below native; our temperature
        // ladder stops at "boost paused".
        case .protecting: return thermal.currentLimits.dimTo != nil ? .dimmed : .paused
        }
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
        // The *running* state, not the saved preference — a display change
        // during the launch licence check must not bring the boost up early.
        guard isEnabled else { return }
        // While suspended for heat the triggers must stay down, even if the
        // display set changes underneath us.
        guard !heatSuspended else { return }

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

    // MARK: - Heat suspension

    /// Bring the EDR triggers down when the Mac is too hot, and back up once it
    /// has cooled. This is the half of thermal protection the gamma lift can't
    /// do: the triggers are what keep the compositor in EDR mode, so until they
    /// go the panel stays in HDR with its backlight budget open, however far the
    /// gamma has been dimmed.
    private func applyHeatSuspension(_ limits: ThermalMonitor.Limits) {
        if limits.engagesEDR {
            guard heatSuspended else { return }
            heatSuspended = false
            NSLog("MaxCandela: cooled off — re-engaging EDR")
            rebuildOverlays()
        } else {
            guard !heatSuspended else { return }
            heatSuspended = true
            NSLog("MaxCandela: too hot — cutting the boost and dropping EDR")
            // The triggers stay up for now. The lift is still on the glass, and
            // headroom collapsing under lifted pixels clips them to white, so
            // the fade to the new (unboosted) target has to land first —
            // refreshTargets/animationTick call dropTriggersIfHeatSuspended()
            // once it has.
        }
    }

    /// Take the triggers down once every display has reached its faded target.
    /// No gamma restore here — `refreshTargets` keeps driving the gamma target,
    /// which is already 1.0 (or the OS-critical dim) by the time we get here.
    private func dropTriggersIfHeatSuspended() {
        guard heatSuspended, !overlays.isEmpty else { return }
        let settled = targetScales.allSatisfy { id, target in
            abs((currentScales[id] ?? 1.0) - target) <= 0.001
        }
        guard settled else { return }

        for overlay in overlays.values {
            overlay.deactivate()
        }
        overlays.removeAll()
    }

    // MARK: - Target computation + fade

    /// Recompute per-display targets from the live headroom and the heat guard,
    /// and kick the animator if anything needs to move.
    private func refreshTargets() {
        // Feed the heat model what's actually on the glass, on the display
        // being driven hardest — not what the user asked for.
        let appliedBoost = currentScales.values.max() ?? 1.0
        let limits = thermal.evaluate(appliedBoost: appliedBoost)
        applyHeatSuspension(limits)

        var needsAnimation = false
        for info in displayManager.currentDisplays() where info.supportsBoost {
            // The trigger patch rides the same thermal ceiling as the lift. It
            // is what holds the compositor in EDR mode, so leaving it at full
            // headroom while only the gamma comes down would dim the picture
            // without shedding any heat — the panel would stay in HDR mode.
            overlays[info.displayID]?.renderer.boost =
                Self.targetScale(requested: max(1.0, info.currentHeadroom),
                                 currentHeadroom: info.currentHeadroom,
                                 thermalCeiling: limits.boostCeiling)

            let target = Self.targetScale(requested: requestedBoost,
                                          currentHeadroom: info.currentHeadroom,
                                          thermalCeiling: limits.boostCeiling,
                                          dimTo: limits.dimTo)
            if targetScales[info.displayID] != target {
                targetScales[info.displayID] = target
                NSLog("MaxCandela: display %u headroom %.2f× thermal(ceil %.2f dim %@) → fading to %.2f× (requested %.2f×)",
                      info.displayID, info.currentHeadroom, limits.boostCeiling,
                      limits.dimTo.map { String(format: "%.2f", $0) } ?? "none",
                      target, requestedBoost)
            }
            if abs((currentScales[info.displayID] ?? 1.0) - target) > 0.001 {
                needsAnimation = true
            }
        }
        if needsAnimation {
            startAnimatorIfNeeded()
        } else {
            // Targets are fresh and nothing has to move, so any pending
            // heat teardown is safe to complete now.
            dropTriggersIfHeatSuspended()
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
            // The fade has landed, so it's now safe to drop the triggers.
            dropTriggersIfHeatSuspended()
        }
    }
}
