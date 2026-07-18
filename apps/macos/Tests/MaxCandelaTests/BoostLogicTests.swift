import XCTest
@testable import MaxCandela

/// Pure-logic tests for the boost pipeline: LUT construction and target-scale
/// clamping. The actual backlight/gamma effect requires real EDR hardware —
/// see the verification notes in CLAUDE.md.
final class BoostLogicTests: XCTestCase {

    // MARK: - GammaController LUT

    func testLiftTableIsLinearRampTimesScale() {
        let table = GammaController.makeLiftTable(scale: 2.0, count: 5)
        XCTAssertEqual(table, [0.0, 0.5, 1.0, 1.5, 2.0])
    }

    func testLiftTableWithUnitScaleIsIdentityRamp() {
        let table = GammaController.makeLiftTable(scale: 1.0, count: 256)
        XCTAssertEqual(table.count, 256)
        XCTAssertEqual(table.first, 0.0)
        XCTAssertEqual(table.last, 1.0)
        // Monotonically increasing.
        XCTAssertTrue(zip(table, table.dropFirst()).allSatisfy { $0 <= $1 })
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
