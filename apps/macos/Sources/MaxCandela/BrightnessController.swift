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

    /// The scale a display sits at while the boost is not driving it: Extra
    /// Dim if the licence allows adjustments, otherwise native. Pure,
    /// unit-tested. Clamped to `minimumDim` so a stored or dragged value can
    /// never black the screen out, and to 1.0 so it can never *lift*.
    static func idleScale(extraDim: CGFloat, licensed: Bool) -> CGFloat {
        guard licensed else { return 1.0 }
        return min(1.0, max(GammaController.minimumDim, extraDim))
    }

    /// Whether the boost should be held off for the power source. Pure,
    /// unit-tested.
    static func shouldPauseForBattery(optionOn: Bool, onBattery: Bool) -> Bool {
        optionOn && onBattery
    }

    /// Which displays the user has actually taken out of the boost. Pure,
    /// unit-tested. A saved exclusion only counts while there is a choice to
    /// make: with one boost-capable display attached — or if it would leave
    /// none boosted — it is ignored, because the menu only offers the
    /// per-display rows when there are several, and a laptop undocked from its
    /// monitors must not be left with a toggle that does nothing.
    static func effectiveExclusions(boostCapable: [String], excluded: Set<String>) -> Set<String> {
        let present = excluded.intersection(boostCapable)
        guard boostCapable.count > 1, present.count < Set(boostCapable).count else { return [] }
        return present
    }

    /// "Boost Only In": whether the frontmost app lets the boost run. Pure,
    /// unit-tested. No chosen apps means no restriction.
    static func appRuleAllows(frontmost: String?, chosen: Set<String>) -> Bool {
        guard !chosen.isEmpty else { return true }
        guard let frontmost else { return false }
        return chosen.contains(frontmost)
    }

    private let displayManager = DisplayManager()
    private let power = PowerMonitor()
    private let gamma = GammaController()
    private let thermal = ThermalMonitor()
    private let prefs = Preferences.shared
    private var overlays: [CGDirectDisplayID: EDROverlayWindow] = [:]

    /// What's on the glass right now vs. where the fade is heading.
    private var currentScales: [CGDirectDisplayID: CGFloat] = [:]
    private var targetScales: [CGDirectDisplayID: CGFloat] = [:]

    /// Targets a display has refused the lift for. Not retried until the
    /// target itself moves — retrying an unchanged one on every 0.25 s poll
    /// only filled the log with two lines per tick, indefinitely.
    private var refusedTargets: [CGDirectDisplayID: CGFloat] = [:]

    private var pollTimer: Timer?
    private var animationTimer: Timer?

    /// Set when the heat guard has cut the boost. The EDR triggers stay up
    /// until the gamma fade has landed and come back down only once the Mac has
    /// cooled — the boost stays "on" from the user's point of view throughout,
    /// so `prefs.isEnabled` is deliberately untouched.
    private var heatSuspended = false

    /// The user-requested boost multiplier (unclamped). 1.0 == native.
    private(set) var requestedBoost: CGFloat

    /// Extra Dim (1.0 == off) and Warmth (0 == neutral) as the user set them.
    /// What reaches the glass also depends on the licence — see `idleScale`
    /// and `effectiveWarmth`.
    private(set) var extraDim: CGFloat
    private(set) var warmth: CGFloat

    /// Whether the licence currently allows the boost and the adjustments.
    /// False until MenuBarController has resolved it — the same reason the
    /// persisted boost is not restored from `init`.
    private var licensed = false

    /// The boost is held off because the Mac is on battery and the user asked
    /// for that. Like a licence suspension it leaves `prefs.isEnabled` alone,
    /// so plugging back in restores the boost. Cleared by any explicit toggle:
    /// a user who switches the boost on while on battery means it.
    private(set) var pausedForBattery = false

    /// The boost is held off because the frontmost app is not one of the
    /// "Boost Only In" apps. Same contract as `pausedForBattery`.
    private(set) var pausedForApp = false

    /// The last app to come forward that was not us. Our own alerts activate
    /// the app, and judging the rule against ourselves would drop the boost
    /// every time a dialog of ours opened.
    private var frontmostBundleID: String?
    private var appObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var warmthTimer: Timer?

    /// Fired when the running state changes without the user clicking —
    /// battery or app-rule pause/resume — so the menu-bar icon can follow.
    var onStateChange: (() -> Void)?

    init() {
        self.requestedBoost = CGFloat(prefs.boost)
        self.extraDim = Self.idleScale(extraDim: CGFloat(prefs.extraDim), licensed: true)
        self.warmth = max(0, min(1, CGFloat(prefs.warmth)))
        displayManager.onScreenConfigurationChanged = { [weak self] in
            self?.rebuildOverlays()
            // A display that just arrived has none of the adjustments yet.
            self?.applyIdleState()
        }
        power.onChange = { [weak self] in
            self?.powerSourceChanged()
        }
        _ = wasPausingForBattery   // capture the launch-time answer

        let ownPID = ProcessInfo.processInfo.processIdentifier
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != ownPID {
            frontmostBundleID = front.bundleIdentifier
        }
        appObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != ownPID else { return }
            self?.frontmostBundleID = app.bundleIdentifier
            self?.appRuleChanged()
        }

        // Warmth "Only at Night": re-evaluated twice a minute. With the
        // schedule off the factor is a constant 1 and the tick does nothing.
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.warmthScheduleTick()
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        warmthTimer = timer
        // A Mac that slept through the evening wakes up hours past the ramp.
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.warmthScheduleTick()
        }
        // React the instant the Mac heats up or cools, not just on the next poll.
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
        pausedForBattery = false
        pausedForApp = false
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
        pausedForBattery = false
        pausedForApp = false
        heatSuspended = false
        stopTimers()
        teardownAllOverlays()
    }

    /// Restore the boost the user left on last session. Split out of `init` so
    /// it can run *after* the licence check — see the note there.
    func restorePersistedBoostIfWanted() {
        guard prefs.isEnabled, !isEnabled else { return }
        resumeIfStillWanted()
    }

    /// Bring the saved boost up unless something is holding it off. The one
    /// place the holds are weighed, so the licence, the power source and the
    /// app rule cannot each hand the boost back behind the others' backs.
    /// Runs on every licence refresh, so it must also not *undo* a hold.
    private func resumeIfStillWanted() {
        guard prefs.isEnabled, licensed, !isEnabled else { return }
        if !appRuleAllowsNow {
            pausedForApp = true
            return
        }
        // On battery with the option on, the saved boost stays an intent
        // until the Mac is plugged in.
        if Self.shouldPauseForBattery(optionOn: prefs.pauseOnBattery, onBattery: power.isOnBattery) {
            pausedForBattery = true
            return
        }
        enable()
    }

    /// The licence check came back valid: the adjustments may reach the glass.
    func setLicensed() {
        guard !licensed else { return }
        licensed = true
        applyIdleState()
        reapplyDrivenDisplays()
    }

    /// Stop boosting because the licence no longer allows it, *without*
    /// discarding the user's saved preference — buying or restoring should
    /// bring their setting straight back rather than making them re-toggle.
    ///
    /// Extra Dim and Warmth are suspended with it (also keeping their saved
    /// values): `licensed` going false makes the idle state native again.
    func suspendForLicense() {
        licensed = false
        pausedForBattery = false
        pausedForApp = false
        isEnabled = false
        heatSuspended = false
        stopTimers()
        teardownAllOverlays()
    }

    // MARK: - Pause on battery

    var pauseOnBattery: Bool {
        get { prefs.pauseOnBattery }
        set {
            prefs.pauseOnBattery = newValue
            powerSourceChanged()
        }
    }

    /// The last answer acted on. The notification also fires on every
    /// charge-percentage tick; acting only on a *change* is what lets a boost
    /// the user switched on by hand while on battery survive the next tick.
    private lazy var wasPausingForBattery =
        Self.shouldPauseForBattery(optionOn: prefs.pauseOnBattery, onBattery: power.isOnBattery)

    private func powerSourceChanged() {
        let shouldPause = Self.shouldPauseForBattery(optionOn: prefs.pauseOnBattery,
                                                     onBattery: power.isOnBattery)
        guard shouldPause != wasPausingForBattery else { return }
        wasPausingForBattery = shouldPause

        if shouldPause {
            guard isEnabled else { return }
            NSLog("MaxCandela: on battery — pausing the boost")
            isEnabled = false
            heatSuspended = false
            stopTimers()
            teardownAllOverlays()
            pausedForBattery = true
            onStateChange?()
        } else if pausedForBattery {
            pausedForBattery = false
            // The trial can run out while paused; `licensed` (checked in
            // resumeIfStillWanted) is what stops plugging in from quietly
            // handing the boost back.
            NSLog("MaxCandela: back on power")
            resumeIfStillWanted()
            onStateChange?()
        }
    }

    // MARK: - Boost only in chosen apps

    /// Bundle identifier → name. Empty means the boost runs in every app.
    var boostApps: [String: String] {
        get { prefs.boostApps }
        set {
            prefs.boostApps = newValue
            appRuleChanged()
        }
    }

    private var appRuleAllowsNow: Bool {
        Self.appRuleAllows(frontmost: frontmostBundleID, chosen: Set(prefs.boostApps.keys))
    }

    /// Called when another app comes forward or the list is edited. A boost
    /// the user switches on by hand in an app that is not on the list stays
    /// up only until the next app switch — the rule is re-judged then.
    private func appRuleChanged() {
        if !appRuleAllowsNow {
            guard isEnabled else { return }
            isEnabled = false
            heatSuspended = false
            stopTimers()
            teardownAllOverlays()
            pausedForApp = true
            onStateChange?()
        } else if pausedForApp {
            pausedForApp = false
            resumeIfStillWanted()
            onStateChange?()
        }
    }

    // MARK: - Per-display boost

    /// The displays the boost drives: capable of it, and not taken out by the
    /// user. Everything that used to ask `supportsBoost` to decide what to
    /// *drive* asks this instead.
    private func boostTargets(in displays: [DisplayInfo]) -> [DisplayInfo] {
        let capable = displays.filter(\.supportsBoost)
        let excluded = Self.effectiveExclusions(boostCapable: capable.map(\.stableID),
                                                excluded: prefs.excludedDisplays)
        return capable.filter { !excluded.contains($0.stableID) }
    }

    func setDisplay(_ stableID: String, boosted: Bool) {
        var excluded = prefs.excludedDisplays
        if boosted { excluded.remove(stableID) } else { excluded.insert(stableID) }
        prefs.excludedDisplays = excluded
        // Same path as a monitor being unplugged: the display that left the
        // set fades back, a new one gets its trigger.
        rebuildOverlays()
    }

    // MARK: - Extra Dim + Warmth

    /// Warmth that actually reaches the glass.
    private var effectiveWarmth: CGFloat { licensed ? warmth * scheduleFactor : 0 }

    /// While the Warmth slider is being dragged the schedule is ignored, so
    /// setting it at noon still shows what is being set.
    private var warmthPreviewUntil: Date?
    private var lastScheduleFactor: CGFloat = 1

    private var scheduleFactor: CGFloat {
        guard prefs.warmthScheduled else { return 1 }
        if let until = warmthPreviewUntil, Date() < until { return 1 }
        return CGFloat(WarmthSchedule.factor(minuteOfDay: WarmthSchedule.minuteOfDay(),
                                             startHour: prefs.warmthStartHour,
                                             endHour: prefs.warmthEndHour))
    }

    private func warmthScheduleTick() {
        let factor = scheduleFactor
        guard factor != lastScheduleFactor else { return }
        lastScheduleFactor = factor
        applyIdleState()
        reapplyDrivenDisplays()
    }

    var warmthSchedule: (enabled: Bool, startHour: Int, endHour: Int) {
        get { (prefs.warmthScheduled, prefs.warmthStartHour, prefs.warmthEndHour) }
        set {
            prefs.warmthScheduled = newValue.enabled
            prefs.warmthStartHour = newValue.startHour
            prefs.warmthEndHour = newValue.endHour
            warmthPreviewUntil = nil
            warmthScheduleTick()
        }
    }

    private var idleScale: CGFloat { Self.idleScale(extraDim: extraDim, licensed: licensed) }

    /// Slider entry points. Applied as hard table writes rather than through
    /// the fade animator: a slider drag already arrives as a stream of small
    /// steps, which is the fade.
    func setExtraDim(_ value: CGFloat) {
        extraDim = Self.idleScale(extraDim: value, licensed: true)
        prefs.extraDim = Double(extraDim)
        applyIdleState()
    }

    func setWarmth(_ value: CGFloat) {
        warmth = max(0, min(1, value))
        prefs.warmth = Double(warmth)
        if prefs.warmthScheduled {
            warmthPreviewUntil = Date().addingTimeInterval(4)
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.2) { [weak self] in
                self?.warmthScheduleTick()
            }
        }
        lastScheduleFactor = scheduleFactor
        applyIdleState()
        reapplyDrivenDisplays()
    }

    /// The displays whose scale the boost owns right now. Everything else
    /// sits at the idle state.
    private func drivenIDs(in displays: [DisplayInfo]) -> Set<CGDirectDisplayID> {
        guard isEnabled else { return [] }
        return Set(boostTargets(in: displays).map(\.displayID))
    }

    /// Put every display the boost is not driving at Extra Dim + Warmth — or,
    /// when the boost is off and neither is set, hand the displays back to
    /// ColorSync exactly as before these adjustments existed.
    private func applyIdleState() {
        let scale = idleScale
        let warm = effectiveWarmth
        let neutral = scale == 1.0 && warm == 0

        if !isEnabled && neutral {
            if !currentScales.isEmpty {
                currentScales.removeAll()
                gamma.restoreAll()
            }
            return
        }
        let displays = displayManager.currentDisplays()
        let driven = drivenIDs(in: displays)
        for info in displays where !driven.contains(info.displayID) {
            let id = info.displayID
            // Never touched and nothing to apply: leave its tables alone.
            if neutral && currentScales[id] == nil { continue }
            // Any fade still aimed at this display is superseded.
            targetScales[id] = nil
            if gamma.apply(scale: scale, warmth: warm, to: id) {
                currentScales[id] = scale
            }
        }
    }

    /// Re-write the boosted displays at their current scale so a warmth change
    /// shows without waiting for the next fade.
    private func reapplyDrivenDisplays() {
        guard isEnabled else { return }
        for id in drivenIDs(in: displayManager.currentDisplays()) {
            guard let current = currentScales[id] else { continue }
            gamma.apply(scale: current, warmth: effectiveWarmth, to: id)
        }
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
        // The teardown leaves Extra Dim / Warmth on the glass by design; a
        // quit must not. (Gamma is per-process and would revert on exit
        // anyway — this is the explicit half of "quit == back to normal".)
        currentScales.removeAll()
        gamma.restoreAll()
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

    /// One display's live boost position: what we've applied, what the panel
    /// currently allows, and therefore how much lift is still unused.
    ///
    /// Reported per display rather than as a single best-of figure — headroom
    /// is a ratio against *that* panel's SDR white, so a built-in XDR panel and
    /// an external HDR monitor produce numbers that mean different things and
    /// must never be collapsed into one.
    struct DisplayStatus {
        let name: String
        let applied: CGFloat
        let headroom: CGFloat
        /// `DisplayInfo.stableID`, for the menu's per-display switch.
        var id = ""
        /// Taken out of the boost by the user.
        var isExcluded = false

        /// Boost still available on this panel; 0 once it is driven to its
        /// current ceiling.
        /// `applied` can sit below 1.0 (Extra Dim, a thermal dim); that is not
        /// extra headroom, so it is floored at native here.
        var remaining: CGFloat { max(0, headroom - max(1.0, applied)) }

        /// Live headroom sits at ~1.0 until something engages EDR, so below
        /// that threshold the value describes nothing the user would recognise
        /// and is not worth showing.
        var isMeaningful: Bool { headroom > 1.05 }
    }

    /// Live per-display status for the menu, boost-capable displays only.
    func displayStatuses() -> [DisplayStatus] {
        let capable = displayManager.currentDisplays().filter(\.supportsBoost)
        let excluded = Self.effectiveExclusions(boostCapable: capable.map(\.stableID),
                                                excluded: prefs.excludedDisplays)
        return capable.map { info in
            DisplayStatus(name: info.screen.localizedName,
                          applied: currentScales[info.displayID] ?? 1.0,
                          headroom: info.currentHeadroom,
                          id: info.stableID,
                          isExcluded: excluded.contains(info.stableID))
        }
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

    // MARK: - Poll loop

    /// How often live headroom is re-read. Chosen for *user-visible* latency:
    /// turning the brightness slider moves SDR white, which moves headroom, and
    /// the boost has to follow within a fade the user reads as immediate. At
    /// 1 s the clamp lagged the slider by up to a second before the fade even
    /// started. Cheap to run — it reads NSScreen properties, no I/O — and the
    /// heat model integrates over real elapsed time (`advanceExposure`), so
    /// tick length does not perturb the thermal ladder.
    private static let pollInterval: TimeInterval = 0.25

    /// EDR headroom ramps up over a few seconds after the trigger appears and
    /// drifts with thermals/battery — poll it and follow (never cache).
    private func startPolling() {
        pollTimer?.invalidate()
        let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
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

        let displays = displayManager.currentDisplays()
        // uniquingKeysWith: mirrored screens can report duplicate display IDs;
        // uniqueKeysWithValues would trap on that.
        let infoByID = Dictionary(displays.map { ($0.displayID, $0) },
                                  uniquingKeysWith: { first, _ in first })
        let wanted = Set(boostTargets(in: displays).map(\.displayID))
        let existing = Set(overlays.keys)

        // Even when the display set is unchanged, a resolution or arrangement
        // change moves the screen out from under its trigger — whose frame is
        // in global coordinates — and a trigger that is off its display holds
        // no EDR open. Re-parking is a window move: no gamma, no flicker.
        for id in existing.intersection(wanted) {
            if let info = infoByID[id] {
                overlays[id]?.place(on: info.screen)
            }
        }
        guard wanted != existing else {
            refreshTargets()
            return
        }

        // Remove triggers for displays that left the boost set (no global
        // gamma restore — it would flash the surviving displays). One that is
        // still attached but lost its headroom (HDR switched off, an SDR
        // reference preset) still carries our lift, and refreshTargets only
        // drives boost-capable displays: fade it back to native here rather
        // than forgetting it. Keeping its entry is also what makes
        // `teardownAllOverlays` restore it if the user switches off.
        var fadingBack = false
        for id in existing.subtracting(wanted) {
            overlays[id]?.deactivate()
            overlays[id] = nil
            refusedTargets[id] = nil
            if infoByID[id] != nil, let current = currentScales[id], current != idleScale {
                targetScales[id] = idleScale
                fadingBack = true
            } else {
                currentScales[id] = nil
                targetScales[id] = nil
            }
        }
        if fadingBack {
            startAnimatorIfNeeded()
        }

        // Add triggers for new displays.
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
        refusedTargets.removeAll()
        // Every caller has already cleared `isEnabled`, so this either
        // restores ColorSync (no adjustments — the original behaviour) or
        // swaps the lift for Extra Dim / Warmth in one table write.
        applyIdleState()
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
        // The thermal notification calls in here whatever the boost is doing.
        // Off (or suspended for the licence) there is nothing to drive: without
        // this guard another app's HDR content raised live headroom and the
        // lift came up anyway, with no poll running to ever bring it back down.
        // It also kept the heat model's clock ticking, which robbed the next
        // switch-on of the cooling credit for the time spent off.
        guard isEnabled else { return }

        // Feed the heat model what's actually on the glass, on the display
        // being driven hardest — not what the user asked for.
        let appliedBoost = currentScales.values.max() ?? 1.0
        let limits = thermal.evaluate(appliedBoost: appliedBoost)
        applyHeatSuspension(limits)

        var needsAnimation = false
        for info in boostTargets(in: displayManager.currentDisplays()) {
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
            // Already refused this exact target: leave the display parked
            // where it stopped until the target moves (see refusedTargets).
            if refusedTargets[info.displayID] == target { continue }
            refusedTargets[info.displayID] = nil
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
            if gamma.apply(scale: next, warmth: effectiveWarmth, to: id) {
                // Only record progress the display actually accepted — otherwise
                // displayStatuses() would report a boost that isn't on the glass.
                currentScales[id] = next
                if next != target {
                    allSettled = false
                }
            } else {
                // Display refused the lift: stop chasing it instead of
                // spinning the animator forever. Retried once the target
                // moves — refreshTargets skips a target already refused.
                refusedTargets[id] = target
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
