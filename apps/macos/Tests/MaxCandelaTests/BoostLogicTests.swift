import XCTest
@testable import MaxCandela

/// Pure-logic tests for the boost pipeline: LUT construction and target-scale
/// clamping. The actual backlight/gamma effect requires real EDR hardware —
/// see the verification notes in CLAUDE.md.
final class BoostLogicTests: XCTestCase {

    // MARK: - GammaController math

    func testEncodedGainConvertsLuminanceScaleThroughGamma() {
        // Luminance ×2 through a 2.2 display curve needs 2^(1/2.2) ≈ 1.37 in
        // encoded space — NOT ×2, which would over-drive luminance ~4.6×.
        XCTAssertEqual(GammaController.encodedGain(forLuminanceScale: 2.0), pow(2.0, 1 / 2.2), accuracy: 0.0001)
        XCTAssertEqual(GammaController.encodedGain(forLuminanceScale: 1.0), 1.0)
        // Degenerate input never dims or explodes.
        XCTAssertEqual(GammaController.encodedGain(forLuminanceScale: 0.0), 1.0)
    }

    func testLiftTablePreservesCurveShape() {
        // A non-linear "calibration" base must keep its shape, just scaled —
        // that's what preserves color. Every entry scales by the same gain.
        let base: [Float] = [0.0, 0.1, 0.35, 0.7, 1.0]
        let lifted = GammaController.liftTable(base: base, luminanceScale: 2.0)
        let gain = GammaController.encodedGain(forLuminanceScale: 2.0)
        XCTAssertEqual(lifted.count, base.count)
        for (b, l) in zip(base, lifted) {
            XCTAssertEqual(l, b * gain, accuracy: 0.0001)
        }
    }

    func testLiftTableWithUnitScaleIsUnchanged() {
        let base: [Float] = [0.0, 0.25, 0.5, 0.75, 1.0]
        XCTAssertEqual(GammaController.liftTable(base: base, luminanceScale: 1.0), base)
    }

    // MARK: - StoreManager trial clock

    func testTrialFullOnFirstDay() {
        let start = Date()
        XCTAssertEqual(StoreManager.trialDaysRemaining(firstLaunch: start, now: start), 5)
    }

    func testTrialCountsDownByWholeDays() {
        let start = Date()
        let threeDaysLater = start.addingTimeInterval(3 * 86_400 + 60)
        XCTAssertEqual(StoreManager.trialDaysRemaining(firstLaunch: start, now: threeDaysLater), 2)
    }

    func testTrialExpiresAtZeroAndStaysThere() {
        let start = Date()
        let sixDaysLater = start.addingTimeInterval(6 * 86_400)
        XCTAssertEqual(StoreManager.trialDaysRemaining(firstLaunch: start, now: sixDaysLater), 0)
        let yearLater = start.addingTimeInterval(365 * 86_400)
        XCTAssertEqual(StoreManager.trialDaysRemaining(firstLaunch: start, now: yearLater), 0)
    }

    func testTrialExpiresExactlyAtTheEndOfDayFive() {
        // The precise boundary the paywall hangs off, pinned so a refactor of
        // the day arithmetic can't quietly hand out a sixth day (or steal one).
        let start = Date()
        XCTAssertEqual(StoreManager.trialDaysRemaining(firstLaunch: start,
                                                       now: start.addingTimeInterval(5 * 86_400 - 1)), 1)
        XCTAssertEqual(StoreManager.trialDaysRemaining(firstLaunch: start,
                                                       now: start.addingTimeInterval(5 * 86_400)), 0)
    }

    func testTrialLenientWhenClockRolledBack() {
        let start = Date()
        let past = start.addingTimeInterval(-86_400)
        XCTAssertEqual(StoreManager.trialDaysRemaining(firstLaunch: start, now: past), 5)
    }

    // MARK: - BrightnessController target scale

    func testTargetScaleClampsToHeadroom() {
        // User wants 16×, panel currently allows 1.6× → follow the OS ceiling.
        XCTAssertEqual(BrightnessController.targetScale(requested: 16.0, currentHeadroom: 1.6), 1.6)
    }

    func testTargetScaleHonorsRequestBelowHeadroom() {
        XCTAssertEqual(BrightnessController.targetScale(requested: 1.3, currentHeadroom: 2.0), 1.3)
    }

    func testTargetScaleNeverDropsBelowNative() {
        // Headroom can read < 1.0 transiently on non-EDR paths; never dim.
        XCTAssertEqual(BrightnessController.targetScale(requested: 2.0, currentHeadroom: 0.5), 1.0)
        XCTAssertEqual(BrightnessController.targetScale(requested: 0.0, currentHeadroom: 2.0), 1.0)
    }

    // MARK: - Thermal limits

    func testThermalLimitsMapping() {
        XCTAssertEqual(ThermalMonitor.limits(ceiling: 1.0, thermalState: .nominal),
                       .init(boostCeiling: 1.0, dimTo: nil, engagesEDR: true))
        XCTAssertEqual(ThermalMonitor.limits(ceiling: ThermalMonitor.easedCeiling, thermalState: .nominal),
                       .init(boostCeiling: ThermalMonitor.easedCeiling, dimTo: nil, engagesEDR: true))
        XCTAssertLessThan(ThermalMonitor.easedCeiling, 1.0)
    }

    func testProtectingCutsBoostAndDropsEDR() {
        // The whole point: a gamma dim alone leaves the panel in HDR mode, so
        // protecting must also disengage EDR.
        let limits = ThermalMonitor.limits(ceiling: 0.0, thermalState: .nominal)
        XCTAssertEqual(limits.boostCeiling, 0.0)
        XCTAssertFalse(limits.engagesEDR)
        // Heat alone never dims below native — that would surprise the user.
        XCTAssertNil(limits.dimTo)
    }

    func testAnyLiveCeilingKeepsEDREngaged() {
        // Only a zero ceiling drops EDR; easing must not, or the boost would
        // blink out at the first sign of warmth.
        XCTAssertTrue(ThermalMonitor.limits(ceiling: 0.05, thermalState: .nominal).engagesEDR)
    }

    func testOSCriticalAlsoDimsBelowNative() {
        let limits = ThermalMonitor.limits(ceiling: 0.0, thermalState: .critical)
        XCTAssertEqual(limits.dimTo, ThermalMonitor.criticalDim)
        XCTAssertFalse(limits.engagesEDR)
        XCTAssertLessThan(ThermalMonitor.criticalDim, 1.0)
    }

    // MARK: - Heat staging

    func testOSThermalStateMapsToStages() {
        XCTAssertEqual(ThermalMonitor.stage(for: .nominal), .normal)
        XCTAssertEqual(ThermalMonitor.stage(for: .fair), .normal)
        XCTAssertEqual(ThermalMonitor.stage(for: .serious), .eased)
        XCTAssertEqual(ThermalMonitor.stage(for: .critical), .protecting)
    }

    func testTemperatureLadderRises() {
        let cool = ThermalMonitor.easeAboveC - 5
        XCTAssertEqual(ThermalMonitor.temperatureStage(previous: .normal, temperatureC: cool), .normal)
        XCTAssertEqual(ThermalMonitor.temperatureStage(previous: .normal,
                                                       temperatureC: ThermalMonitor.easeAboveC), .eased)
        XCTAssertEqual(ThermalMonitor.temperatureStage(previous: .normal,
                                                       temperatureC: ThermalMonitor.protectAboveC), .protecting)
        // A jump straight past both thresholds must not stop at .eased.
        XCTAssertEqual(ThermalMonitor.temperatureStage(previous: .eased,
                                                       temperatureC: ThermalMonitor.protectAboveC + 3), .protecting)
    }

    func testTemperatureLadderHasHysteresis() {
        // Just below the entry threshold must NOT step back down — the sensor
        // lags the panel by minutes, so a narrow band would oscillate.
        let justUnderEase = ThermalMonitor.easeAboveC - 0.1
        XCTAssertEqual(ThermalMonitor.temperatureStage(previous: .eased, temperatureC: justUnderEase), .eased)
        let justUnderProtect = ThermalMonitor.protectAboveC - 0.1
        XCTAssertEqual(ThermalMonitor.temperatureStage(previous: .protecting,
                                                       temperatureC: justUnderProtect), .protecting)
        // Clearing the margin does step back down.
        XCTAssertEqual(
            ThermalMonitor.temperatureStage(previous: .eased,
                                            temperatureC: ThermalMonitor.easeAboveC
                                                - ThermalMonitor.recoveryMarginC - 0.1),
            .normal)
        XCTAssertEqual(
            ThermalMonitor.temperatureStage(previous: .protecting,
                                            temperatureC: ThermalMonitor.protectAboveC
                                                - ThermalMonitor.recoveryMarginC - 0.1),
            .eased)
    }

    func testMissingThermometerSilencesTemperatureAxisOnly() {
        // Desktop Macs have no battery sensor. That must not fake a safe
        // reading for the OS axis.
        XCTAssertEqual(ThermalMonitor.temperatureStage(previous: .protecting, temperatureC: nil), .normal)
        XCTAssertEqual(ThermalMonitor.stage(for: .critical), .protecting)
    }

    func testWorstAxisWins() {
        // Mirrors how the controller combines axes: the lowest ceiling across
        // the proportional panel model and the discrete emergency signals.
        func combined(exposure: Double, temperatureC: Double?,
                      thermalState: ProcessInfo.ThermalState) -> ThermalMonitor.Stage {
            let emergency = max(ThermalMonitor.temperatureStage(previous: .normal,
                                                                temperatureC: temperatureC),
                                ThermalMonitor.stage(for: thermalState))
            return ThermalMonitor.stage(forCeiling: min(ThermalMonitor.exposureCeiling(exposure: exposure),
                                                        ThermalMonitor.ceiling(for: emergency)))
        }

        // Cool panel and chassis, but the SoC is cooking → still eased.
        XCTAssertEqual(combined(exposure: 0, temperatureC: 25, thermalState: .serious), .eased)
        // Hot chassis while the OS is happy → the case the old code missed.
        XCTAssertEqual(combined(exposure: 0, temperatureC: ThermalMonitor.protectAboveC + 1,
                                thermalState: .nominal), .protecting)
        // Everything cool except the panel model → the case that fires in
        // normal use, and the one nothing else can see.
        XCTAssertEqual(combined(exposure: ThermalMonitor.protectAboveExposure,
                                temperatureC: 25, thermalState: .nominal), .protecting)
        // All quiet → full boost.
        XCTAssertEqual(combined(exposure: 0, temperatureC: 25, thermalState: .nominal), .normal)
    }

    // MARK: - Panel exposure model

    /// Run the closed loop — ceiling sets brightness, brightness heats the
    /// panel, heat lowers the ceiling — for `minutes`, returning the ceiling
    /// each minute.
    private func runLoop(headroom: CGFloat, minutes: Int) -> [CGFloat] {
        var exposure = 0.0
        var ceiling: CGFloat = 1.0
        var history: [CGFloat] = []
        for _ in 0..<minutes {
            let applied = 1 + (headroom - 1) * ceiling
            exposure = ThermalMonitor.advanceExposure(exposure, appliedBoost: applied, elapsed: 60)
            ceiling = ThermalMonitor.exposureCeiling(exposure: exposure)
            history.append(ceiling)
        }
        return history
    }

    func testClosedLoopSettlesInsteadOfPulsing() {
        // Regression, found on hardware: a stepped ceiling over a linear heat
        // integrator made the boost cut out, cool, come back at half, climb and
        // cut out again — forever. Four hours in, the ceiling must be steady.
        for headroom: CGFloat in [2.0, 4.0, 16.0] {
            let history = runLoop(headroom: headroom, minutes: 4 * 60)
            let settled = history.suffix(60)
            let spread = (settled.max() ?? 0) - (settled.min() ?? 0)
            XCTAssertLessThan(spread, 0.02,
                              "ceiling should settle at headroom \(headroom), not oscillate")
            XCTAssertGreaterThan(history.last ?? 0, 0,
                                 "and should settle on a usable boost, not collapse to off")
        }
    }

    func testFullBoostIsAllowedForAWhileBeforeEasing() {
        // The boost must not start clawing itself back immediately — that reads
        // as a broken app. Full ceiling for at least the first 15 minutes.
        let history = runLoop(headroom: 4.0, minutes: 60)
        XCTAssertEqual(history[14], 1.0, accuracy: 0.001)
        // …and it must actually ease by the end of the hour.
        XCTAssertLessThan(history[59], 1.0)
    }

    func testHarderDrivenPanelSettlesLower() {
        // More headroom means more heat at the same ceiling, so the equilibrium
        // has to sit lower.
        let small = runLoop(headroom: 2.0, minutes: 4 * 60).last ?? 0
        let large = runLoop(headroom: 16.0, minutes: 4 * 60).last ?? 0
        XCTAssertLessThan(large, small)
    }

    func testExposureNeverAccumulatesAtNativeBrightness() {
        var exposure = 0.0
        for _ in 0..<600 {
            exposure = ThermalMonitor.advanceExposure(exposure, appliedBoost: 1.0, elapsed: 60)
        }
        XCTAssertEqual(exposure, 0.0)
    }

    func testExposureDecaysOnceTheBoostIsOff() {
        var exposure = 1.0
        for _ in 0..<Int(ThermalMonitor.thermalTimeConstantMinutes * 5) {
            exposure = ThermalMonitor.advanceExposure(exposure, appliedBoost: 1.0, elapsed: 60)
        }
        XCTAssertEqual(exposure, 0.0, accuracy: 0.01)
    }

    func testExposureIsClampedToUnitRange() {
        // A long tick (clock jump, wake from sleep) must land in range, not
        // overshoot the way a fixed-rate integrator would.
        XCTAssertEqual(ThermalMonitor.advanceExposure(0.9, appliedBoost: 4.0, elapsed: 86_400),
                       1.0, accuracy: 0.001)
        XCTAssertEqual(ThermalMonitor.advanceExposure(0.1, appliedBoost: 1.0, elapsed: 86_400),
                       0.0, accuracy: 0.001)
    }

    func testCeilingCurveSpansEaseToProtect() {
        XCTAssertEqual(ThermalMonitor.exposureCeiling(exposure: 0), 1.0)
        XCTAssertEqual(ThermalMonitor.exposureCeiling(exposure: ThermalMonitor.easeAboveExposure),
                       1.0, accuracy: 0.001)
        XCTAssertEqual(ThermalMonitor.exposureCeiling(exposure: ThermalMonitor.protectAboveExposure),
                       0.0, accuracy: 0.001)
        XCTAssertEqual(ThermalMonitor.exposureCeiling(exposure: 1.0), 0.0)
    }

    func testCeilingMapsBackToStages() {
        XCTAssertEqual(ThermalMonitor.stage(forCeiling: 1.0), .normal)
        XCTAssertEqual(ThermalMonitor.stage(forCeiling: 0.4), .eased)
        XCTAssertEqual(ThermalMonitor.stage(forCeiling: 0.0), .protecting)
    }

    func testTargetScaleThermalCeilingScalesOnlyTheExtra() {
        // Request 2.0×, plenty of headroom. Ceiling 0.5 halves the extra 1.0.
        XCTAssertEqual(
            BrightnessController.targetScale(requested: 2.0, currentHeadroom: 4.0, thermalCeiling: 0.5),
            1.5, accuracy: 0.0001)
    }

    func testTargetScaleSeriousDoesNotDim() {
        // Ceiling 0.0 without a dim → exactly native, never below.
        XCTAssertEqual(
            BrightnessController.targetScale(requested: 3.0, currentHeadroom: 3.0, thermalCeiling: 0.0),
            1.0)
    }

    func testTargetScaleCriticalDimsBelowNative() {
        // Critical: boost removed AND dimmed to the safety level (0.8).
        XCTAssertEqual(
            BrightnessController.targetScale(requested: 3.0, currentHeadroom: 3.0,
                                             thermalCeiling: 0.0, dimTo: 0.8),
            0.8, accuracy: 0.0001)
    }

    func testTargetScaleDimCapsEvenWithHeadroom() {
        // Even if boost would apply, the dim cap wins when set.
        XCTAssertEqual(
            BrightnessController.targetScale(requested: 4.0, currentHeadroom: 4.0,
                                             thermalCeiling: 1.0, dimTo: 0.8),
            0.8, accuracy: 0.0001)
    }

    func testTargetScaleThermalNominalMatchesOldBehavior() {
        // Ceiling 1.0 is the pre-thermal behavior: clamp to headroom.
        XCTAssertEqual(
            BrightnessController.targetScale(requested: 16.0, currentHeadroom: 1.6, thermalCeiling: 1.0),
            1.6, accuracy: 0.0001)
        // Default arg also means "no thermal effect".
        XCTAssertEqual(
            BrightnessController.targetScale(requested: 1.3, currentHeadroom: 2.0),
            1.3, accuracy: 0.0001)
    }

    func testTargetScaleThermalClampsToHeadroomFirst() {
        // Headroom (1.6) binds before thermal scales the extra 0.6 by 0.5 → 1.3.
        XCTAssertEqual(
            BrightnessController.targetScale(requested: 4.0, currentHeadroom: 1.6, thermalCeiling: 0.5),
            1.3, accuracy: 0.0001)
    }

    // MARK: - Fade animator

    func testAnimationStepApproachesTarget() {
        let next = BrightnessController.animationStep(current: 1.0, target: 2.0)
        XCTAssertEqual(next, 1.3, accuracy: 0.0001)   // 30% of remaining distance
        XCTAssertLessThan(next, 2.0)
    }

    func testAnimationStepSnapsWhenClose() {
        XCTAssertEqual(BrightnessController.animationStep(current: 1.99, target: 2.0), 2.0)
        XCTAssertEqual(BrightnessController.animationStep(current: 2.0, target: 2.0), 2.0)
    }

    func testAnimationStepConvergesFromEitherSide() {
        // Fading down (thermal ceiling drop) must converge too.
        var value: CGFloat = 2.0
        for _ in 0..<50 { value = BrightnessController.animationStep(current: value, target: 1.4) }
        XCTAssertEqual(value, 1.4)
    }

    func testTargetScaleTracksHeadroomDownAndUp() {
        // Simulates a thermal down-ramp and recovery at fixed request.
        let request: CGFloat = 2.0
        XCTAssertEqual(BrightnessController.targetScale(requested: request, currentHeadroom: 2.0), 2.0)
        XCTAssertEqual(BrightnessController.targetScale(requested: request, currentHeadroom: 1.4), 1.4)
        XCTAssertEqual(BrightnessController.targetScale(requested: request, currentHeadroom: 2.0), 2.0)
    }

    // MARK: - Per-display status

    func testRemainingIsZeroWhenDrivenToTheCeiling() {
        let maxed = BrightnessController.DisplayStatus(
            name: "Built-in Retina Display", applied: 3.98, headroom: 3.98)
        XCTAssertEqual(maxed.remaining, 0.0, accuracy: 0.0001)
    }

    func testRemainingReportsUnusedHeadroom() {
        let eased = BrightnessController.DisplayStatus(
            name: "Built-in Retina Display", applied: 1.62, headroom: 4.00)
        XCTAssertEqual(eased.remaining, 2.38, accuracy: 0.0001)
    }

    func testRemainingNeverGoesNegativeWhenDimmedBelowNative() {
        // Thermal .critical dims below 1.0 while headroom collapses; a naive
        // subtraction would print a negative "left" figure at the user.
        let dimmed = BrightnessController.DisplayStatus(
            name: "Built-in Retina Display", applied: 0.8, headroom: 0.5)
        XCTAssertEqual(dimmed.remaining, 0.0)
    }

    func testHeadroomIsNotMeaningfulBeforeEDREngages() {
        // Live headroom idles at ~1.0 until something puts the panel in HDR
        // mode — showing "0.00× left" there would read as "no boost possible".
        XCTAssertFalse(BrightnessController.DisplayStatus(
            name: "Display", applied: 1.0, headroom: 1.0).isMeaningful)
        XCTAssertTrue(BrightnessController.DisplayStatus(
            name: "Display", applied: 1.0, headroom: 4.344).isMeaningful)
    }
}

