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
        XCTAssertEqual(ThermalMonitor.limits(for: .nominal), .init(boostCeiling: 1.0, dimTo: nil))
        XCTAssertEqual(ThermalMonitor.limits(for: .fair), .init(boostCeiling: 1.0, dimTo: nil))
        XCTAssertEqual(ThermalMonitor.limits(for: .serious), .init(boostCeiling: 0.5, dimTo: nil))
        // Critical: no boost AND an active safety dim below normal.
        XCTAssertEqual(ThermalMonitor.limits(for: .critical),
                       .init(boostCeiling: 0.0, dimTo: ThermalMonitor.criticalDim))
        XCTAssertLessThan(ThermalMonitor.criticalDim, 1.0)
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
}
