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

    func testTargetScaleTracksHeadroomDownAndUp() {
        // Simulates a thermal down-ramp and recovery at fixed request.
        let request: CGFloat = 2.0
        XCTAssertEqual(BrightnessController.targetScale(requested: request, currentHeadroom: 2.0), 2.0)
        XCTAssertEqual(BrightnessController.targetScale(requested: request, currentHeadroom: 1.4), 1.4)
        XCTAssertEqual(BrightnessController.targetScale(requested: request, currentHeadroom: 2.0), 2.0)
    }
}
