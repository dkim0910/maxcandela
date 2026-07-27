import Foundation

/// Decides how far the boost must be reined in to protect the Mac.
///
/// **Why this is not just `ProcessInfo.thermalState`.** That property tracks
/// *SoC* thermal pressure, and the boost's heat lands in the panel, not the
/// chip. Measured on an M1 Pro MacBook Pro running the boost: seven days of
/// `thermalmonitord` logs contain zero thermal-level transitions and
/// `pmset -g therm` reports "No thermal warning level has been recorded" — the
/// state never leaves `.nominal` however hot the screen gets. A ladder hung off
/// it alone is unreachable in the one situation it exists for, which is exactly
/// what users hit: a hot display and no protection.
///
/// **Why a modelled axis and not just a thermometer.** macOS exposes no panel
/// thermometer to a sandboxed app — `AppleCLCD2` publishes only a boot-time
/// `InitialPanelTemperature`, `PDCGlobalTemp` reads 0, and the SMC needs a
/// privileged helper. The nearest real sensor is the battery's, and it is
/// thermally isolated from the display: measured on this hardware, twenty
/// minutes of a verified 4.0× boost moved it 30.23 → 30.22 °C. It cannot see
/// panel heat. So the panel axis is *estimated* from how hard and how long we
/// have been driving the backlight — an open-loop thermal model, because
/// nothing closed-loop is available.
///
/// Heat is therefore judged on three axes and the **worst one wins**:
///  - `exposure` — accumulated boost × time, the only axis that responds to the
///    panel heat the boost itself creates. This is the one that fires in normal
///    use.
///  - `ChassisTemperature` — a real thermometer. Blind to display-only heat, but
///    it catches a genuinely hot machine.
///  - `ProcessInfo.thermalState` — kept because it still catches the other case
///    (something else is cooking the SoC while we add to it).
///
/// The response is staged: ease the boost down when hot, and when *too* hot cut
/// it entirely and drop EDR so the panel leaves HDR mode. Nothing below native
/// is touched unless the OS itself declares `.critical`.
///
/// We can't touch fans — that needs SMC access a sandboxed App Store app cannot
/// have (see CLAUDE.md) — so shedding our own heat is the only lever we have.
final class ThermalMonitor {
    /// How hard the boost is currently being held back.
    enum Stage: Int, Comparable {
        /// Full boost.
        case normal = 0
        /// Hot: the boost above native is cut back, EDR stays engaged.
        case eased = 1
        /// Too hot: boost off and EDR disengaged, to stop adding heat at all.
        case protecting = 2

        static func < (lhs: Stage, rhs: Stage) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// What the current stage means for the renderer and the gamma lift.
    struct Limits: Equatable {
        /// Fraction of the boost-above-native still allowed (0…1).
        let boostCeiling: CGFloat
        /// If set, actively dim the whole display to this multiplier of normal
        /// (< 1.0). `nil` means "don't dim below normal".
        let dimTo: CGFloat?
        /// Whether the EDR trigger may stay up. When false the controller must
        /// tear it down: a gamma dim alone leaves the compositor in EDR mode
        /// with the backlight budget still open, so the screen only *looks*
        /// dimmer while the panel keeps heating.
        let engagesEDR: Bool
    }

    // MARK: - Tuning

    /// Chassis temperature (°C) at which the boost starts easing off. Idle on a
    /// MacBook Pro sits around 30 °C; sustained load runs mid-to-high 30s.
    static let easeAboveC: Double = 38.0

    /// Chassis temperature (°C) at which the boost is cut entirely. Above this
    /// the Mac is hot enough that adding backlight power is indefensible — it's
    /// also where macOS starts throttling battery charging.
    static let protectAboveC: Double = 42.0

    /// How far below an entry threshold the temperature must fall before
    /// stepping back down a stage. The sensor lags the panel by minutes, so a
    /// wide band is what stops the boost from oscillating.
    static let recoveryMarginC: Double = 2.0

    /// Fraction of the extra brightness kept while eased.
    static let easedCeiling: CGFloat = 0.5

    // MARK: Panel-exposure model
    //
    // `exposure` runs 0…1 as an estimate of how hot the boost has made the
    // panel. It relaxes toward however hard we are currently driving the
    // backlight (Newton's law of cooling), so holding a given brightness
    // reaches an equilibrium instead of accumulating forever.
    //
    // That equilibrium matters: an earlier version integrated heat linearly and
    // fell back to full boost whenever it cooled, which on hardware made the
    // boost **pulse** — cut out, cool, come back at half, climb, cut out again,
    // roughly every 25 minutes. The response is therefore *proportional*: the
    // ceiling falls smoothly as exposure rises, so the loop settles at whatever
    // brightness the panel can actually sustain and simply stays there.
    //
    // THESE ARE THE TUNING DIALS. A longer time constant or higher thresholds
    // make the app more permissive (hotter screen, less intervention).

    /// How fast the panel-heat estimate tracks a change in brightness. An XDR
    /// panel takes roughly half an hour to reach thermal equilibrium.
    static let thermalTimeConstantMinutes: Double = 30

    /// The lift-above-native treated as "driving the panel flat out". Heat rises
    /// with backlight power, which tracks the luminance multiplier, so a 4×
    /// boost (3.0 extra) counts as full intensity and anything beyond saturates.
    static let referenceExtraBoost: Double = 3.0

    /// Exposure below which the full boost is allowed. Reached after about
    /// 20 minutes at full tilt.
    static let easeAboveExposure: Double = 0.5

    /// Exposure at which the boost is cut entirely. Between the two the ceiling
    /// slides linearly, which is what makes the loop settle rather than pulse.
    static let protectAboveExposure: Double = 0.85

    /// How dark the safety dim goes when the *OS* reports critical thermal
    /// pressure. 0.8 = 80% of normal — noticeable but not jarring, enough to
    /// cut backlight power on top of dropping the boost.
    static let criticalDim: CGFloat = 0.8

    /// Called on every OS thermal-state transition so the controller can
    /// re-evaluate immediately instead of waiting for its 1 s poll.
    ///
    /// Always delivered on the main thread: Foundation posts
    /// `thermalStateDidChangeNotification` on the global dispatch queue (see
    /// NSProcessInfo.h), and the controller's state is main-thread-only.
    var onChange: (() -> Void)?

    /// Latest evaluated stage. Advanced only by `evaluate()`, so reading it
    /// (e.g. to draw the menu) has no side effects.
    private(set) var stage: Stage = .normal

    /// Estimated panel heat, 0 (cold) … 1 (fully exposed). See the model note
    /// in the tuning section.
    private(set) var exposure: Double = 0

    /// When `evaluate()` last ran, so exposure integrates over real elapsed
    /// time rather than assuming a tick rate.
    private var lastEvaluatedAt: Date?

    /// Hysteresis state for the temperature axis alone — it must not be
    /// disturbed by the panel model moving the overall stage around.
    private var temperatureStageState: Stage = .normal

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

    // MARK: - Evaluation

    /// Re-read every heat signal, advance the stage, and return its limits.
    /// Call from the poll loop; this is the only thing that moves `stage`.
    ///
    /// `appliedBoost` is the lift actually on the glass right now (1.0 ==
    /// native) — the exposure model integrates it, so passing the *requested*
    /// boost instead would keep accumulating heat we aren't actually making.
    @discardableResult
    func evaluate(appliedBoost: CGFloat) -> Limits {
        let now = Date()
        let elapsed = lastEvaluatedAt.map { now.timeIntervalSince($0) } ?? 0
        lastEvaluatedAt = now

        // Clock jumps (sleep/wake, time changes) must not dump a day's worth of
        // exposure in one tick, nor credit a day of cooling.
        let step = min(max(elapsed, 0), 60)
        exposure = Self.advanceExposure(exposure, appliedBoost: appliedBoost, elapsed: step)

        // Worst axis wins: the smooth panel ceiling, or whatever the discrete
        // emergency signals allow.
        let state = osThermalState
        temperatureStageState = Self.temperatureStage(previous: temperatureStageState,
                                                      temperatureC: chassisTemperatureC)
        let emergency = max(temperatureStageState, Self.stage(for: state))
        let ceiling = min(Self.exposureCeiling(exposure: exposure),
                          Self.ceiling(for: emergency))

        stage = Self.stage(forCeiling: ceiling)
        return Self.limits(ceiling: ceiling, thermalState: state)
    }

    /// Credit the time the boost spent switched off as cooling, then restart the
    /// integration clock. The poll loop doesn't run while the boost is off, so
    /// without this a long pause would look like no time passed at all and the
    /// user would come back to an immediately-protected screen.
    func creditIdleCooling() {
        guard let last = lastEvaluatedAt else { return }
        let idle = max(0, Date().timeIntervalSince(last))
        exposure = Self.advanceExposure(exposure, appliedBoost: 1.0, elapsed: idle)
        lastEvaluatedAt = nil
    }

    /// Limits for the last evaluated stage — a pure read for the menu.
    var currentLimits: Limits {
        Self.limits(ceiling: Self.ceiling(for: stage), thermalState: osThermalState)
    }

    // MARK: - Pure mapping (unit-tested)

    /// Advance the panel-heat estimate by one tick. Exposure relaxes toward the
    /// intensity currently being driven, so a sustainable brightness reaches
    /// equilibrium and a dropped boost decays away on the same curve.
    ///
    /// The exponential form is exact for any step length, so a long tick (a
    /// clock jump, a wake from sleep) lands on the right value instead of
    /// overshooting the way a fixed-rate integrator would.
    static func advanceExposure(_ exposure: Double,
                                appliedBoost: CGFloat,
                                elapsed: TimeInterval) -> Double {
        let extra = max(0, Double(appliedBoost) - 1.0)
        let intensity = min(1.0, extra / referenceExtraBoost)
        let alpha = 1 - exp(-max(0, elapsed) / (thermalTimeConstantMinutes * 60))
        return min(1.0, max(0.0, exposure + (intensity - exposure) * alpha))
    }

    /// Panel axis: a *proportional* ceiling, full below `easeAboveExposure` and
    /// sliding to zero at `protectAboveExposure`.
    ///
    /// Proportional rather than stepped on purpose. With discrete steps the
    /// eased level still heats the panel, so exposure climbs back to the cut-out
    /// threshold and the boost pulses forever (observed on hardware). Sliding
    /// the ceiling means driving harder always costs headroom, so the loop
    /// settles wherever supply meets demand — and it lands there smoothly.
    static func exposureCeiling(exposure: Double) -> CGFloat {
        let span = protectAboveExposure - easeAboveExposure
        guard span > 0 else { return exposure >= protectAboveExposure ? 0 : 1 }
        let ceiling = (protectAboveExposure - exposure) / span
        return CGFloat(min(1.0, max(0.0, ceiling)))
    }

    /// Ceiling implied by a discrete stage, so the temperature and OS axes can
    /// be combined with the proportional one by taking the lower.
    static func ceiling(for stage: Stage) -> CGFloat {
        switch stage {
        case .normal: return 1.0
        case .eased: return easedCeiling
        case .protecting: return 0.0
        }
    }

    /// The stage a given ceiling represents — what the menu describes.
    static func stage(forCeiling ceiling: CGFloat) -> Stage {
        if ceiling <= 0 { return .protecting }
        return ceiling < 1.0 ? .eased : .normal
    }

    /// Temperature axis, with hysteresis: rising edges use the entry
    /// thresholds, falling edges must clear them by `recoveryMarginC`.
    /// A missing sensor (desktop Mac) silences this axis rather than faking a
    /// safe reading — the OS-state axis still applies.
    static func temperatureStage(previous: Stage, temperatureC: Double?) -> Stage {
        guard let temperature = temperatureC else { return .normal }

        let easeEntry = easeAboveC
        let easeExit = easeAboveC - recoveryMarginC
        let protectEntry = protectAboveC
        let protectExit = protectAboveC - recoveryMarginC

        switch previous {
        case .protecting:
            guard temperature < protectExit else { return .protecting }
            return temperature < easeExit ? .normal : .eased
        case .eased:
            if temperature >= protectEntry { return .protecting }
            return temperature < easeExit ? .normal : .eased
        case .normal:
            if temperature >= protectEntry { return .protecting }
            return temperature >= easeEntry ? .eased : .normal
        }
    }

    /// OS thermal-pressure axis. Reachable in practice only when something
    /// *else* is cooking the SoC — see the note on the type.
    static func stage(for state: ProcessInfo.ThermalState) -> Stage {
        switch state {
        case .nominal, .fair:
            return .normal
        case .serious:
            return .eased
        case .critical:
            return .protecting
        @unknown default:
            return .eased
        }
    }

    /// What a ceiling permits. Only the OS's own `.critical` dims below native;
    /// our own heat ladder stops at "boost off", which protects the panel
    /// without surprising the user with a darker-than-normal screen.
    static func limits(ceiling: CGFloat, thermalState: ProcessInfo.ThermalState) -> Limits {
        guard ceiling > 0 else {
            return Limits(boostCeiling: 0.0,
                          dimTo: thermalState == .critical ? criticalDim : nil,
                          engagesEDR: false)
        }
        return Limits(boostCeiling: ceiling, dimTo: nil, engagesEDR: true)
    }

    // MARK: - Signal sources

    private var osThermalState: ProcessInfo.ThermalState {
        #if DEBUG
        // Force a thermal state for testing: MAXCANDELA_FORCE_THERMAL=serious
        // (or fair/critical/nominal). Real thermal state can't be triggered on
        // demand via public API.
        switch ProcessInfo.processInfo.environment["MAXCANDELA_FORCE_THERMAL"] {
        case "nominal": return .nominal
        case "fair": return .fair
        case "serious": return .serious
        case "critical": return .critical
        default: break
        }
        #endif
        return ProcessInfo.processInfo.thermalState
    }

    private var chassisTemperatureC: Double? {
        #if DEBUG
        // MAXCANDELA_FORCE_TEMP=43.5 fakes the thermometer, so the ease/protect
        // ladder can be walked without actually cooking the Mac.
        if let forced = ProcessInfo.processInfo.environment["MAXCANDELA_FORCE_TEMP"],
           let value = Double(forced) {
            return value
        }
        #endif
        return ChassisTemperature.current()
    }

    @objc private func thermalStateChanged() {
        // Posted on the global dispatch queue; the controller it calls into
        // touches NSScreen and main-thread-only state.
        DispatchQueue.main.async { [weak self] in
            self?.onChange?()
        }
    }
}
