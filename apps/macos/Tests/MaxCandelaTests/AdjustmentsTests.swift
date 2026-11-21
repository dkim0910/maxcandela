import AppKit
import XCTest
@testable import MaxCandela

/// Pure-logic tests for what was added alongside the boost: Extra Dim, Warmth,
/// pause-on-battery and the M5 Pro / M5 Max known-issue check. As with the
/// boost itself, nothing here can observe the glass — see CLAUDE.md.
final class AdjustmentsTests: XCTestCase {

    // MARK: - Warmth

    func testNeutralWarmthLeavesEveryChannelAlone() {
        let gains = GammaController.warmthGains(0)
        XCTAssertEqual(gains.red, 1)
        XCTAssertEqual(gains.green, 1)
        XCTAssertEqual(gains.blue, 1)
    }

    func testWarmthOnlyEverLowersChannels() {
        // The clamp-to-headroom invariant relies on this: warmth must never
        // push a channel above what the luminance scale already put there.
        for step in 0...10 {
            let gains = GammaController.warmthGains(Float(step) / 10)
            XCTAssertEqual(gains.red, 1)
            XCTAssertLessThanOrEqual(gains.green, 1)
            XCTAssertLessThanOrEqual(gains.blue, gains.green)
            XCTAssertGreaterThan(gains.blue, 0)
        }
    }

    func testWarmthIsClampedToItsRange() {
        XCTAssertEqual(GammaController.warmthGains(5).blue, GammaController.warmthGains(1).blue)
        XCTAssertEqual(GammaController.warmthGains(-1).blue, 1)
    }

    // MARK: - Extra Dim

    func testIdleScaleNeverLiftsAndNeverBlacksOut() {
        XCTAssertEqual(BrightnessController.idleScale(extraDim: 0.5, licensed: true), 0.5)
        // A stored value above native must not become a paywall-free boost.
        XCTAssertEqual(BrightnessController.idleScale(extraDim: 3.0, licensed: true), 1.0)
        // Zero (or garbage) must not leave an unusable black screen.
        XCTAssertEqual(BrightnessController.idleScale(extraDim: 0, licensed: true), GammaController.minimumDim)
        XCTAssertEqual(BrightnessController.idleScale(extraDim: -2, licensed: true), GammaController.minimumDim)
    }

    func testIdleScaleIsNativeWithoutALicence() {
        XCTAssertEqual(BrightnessController.idleScale(extraDim: 0.3, licensed: false), 1.0)
    }

    func testDimDoesNotCountAsHeadroomLeft() {
        // Dimmed to 0.5 on a panel reporting 2.0× headroom: 1.0× is left, not
        // 1.5× — being below native is not extra boost.
        let status = BrightnessController.DisplayStatus(name: "x", applied: 0.5, headroom: 2.0)
        XCTAssertEqual(status.remaining, 1.0, accuracy: 0.0001)
    }

    // MARK: - Pause on battery

    func testPauseNeedsBothTheOptionAndTheBattery() {
        XCTAssertTrue(BrightnessController.shouldPauseForBattery(optionOn: true, onBattery: true))
        XCTAssertFalse(BrightnessController.shouldPauseForBattery(optionOn: false, onBattery: true))
        XCTAssertFalse(BrightnessController.shouldPauseForBattery(optionOn: true, onBattery: false))
    }

    func testOnlyTheInternalBatteryCounts() {
        XCTAssertTrue(PowerMonitor.isBattery(providingSourceType: "Battery Power"))
        XCTAssertFalse(PowerMonitor.isBattery(providingSourceType: "AC Power"))
        XCTAssertFalse(PowerMonitor.isBattery(providingSourceType: "UPS Power"))
    }

    // MARK: - Known issues

    func testOnlyTheReportedChipsAreFlagged() {
        XCTAssertTrue(KnownIssues.gammaLiftReportedBroken(chip: "Apple M5 Pro"))
        XCTAssertTrue(KnownIssues.gammaLiftReportedBroken(chip: "Apple M5 Max"))
        // Reported working — must not be warned.
        XCTAssertFalse(KnownIssues.gammaLiftReportedBroken(chip: "Apple M5"))
        XCTAssertFalse(KnownIssues.gammaLiftReportedBroken(chip: "Apple M3 Max"))
        XCTAssertFalse(KnownIssues.gammaLiftReportedBroken(chip: "Apple M1 Pro"))
        XCTAssertFalse(KnownIssues.gammaLiftReportedBroken(chip: ""))
    }

    // MARK: - Warmth schedule (8 PM → 7 AM unless stated)

    private func factor(_ hour: Int, _ minute: Int = 0, start: Int = 20, end: Int = 7) -> Double {
        WarmthSchedule.factor(minuteOfDay: hour * 60 + minute, startHour: start, endHour: end)
    }

    func testScheduleIsOffByDayAndFullAtNight() {
        XCTAssertEqual(factor(12), 0)
        XCTAssertEqual(factor(19, 59), 0)
        XCTAssertEqual(factor(23), 1)
        XCTAssertEqual(factor(3), 1)      // past midnight, same window
        XCTAssertEqual(factor(7), 0)      // the end hour itself is outside
    }

    func testScheduleRampsInsteadOfSwitching() {
        // A hard swap at 8 PM sharp is the thing this exists to avoid.
        XCTAssertEqual(factor(20, 0), 0)
        XCTAssertEqual(factor(20, 15), 0.5, accuracy: 0.0001)
        XCTAssertEqual(factor(20, 30), 1)
        XCTAssertEqual(factor(6, 45), 0.5, accuracy: 0.0001)
    }

    func testScheduleNeverLeavesItsRange() {
        for minute in stride(from: 0, to: 24 * 60, by: 7) {
            let value = WarmthSchedule.factor(minuteOfDay: minute, startHour: 23, endHour: 4)
            XCTAssertGreaterThanOrEqual(value, 0)
            XCTAssertLessThanOrEqual(value, 1)
        }
        // Equal hours mean all day, not never.
        XCTAssertEqual(factor(12, start: 9, end: 9), 1)
    }

    // MARK: - Per-display boost

    func testExclusionAppliesOnlyWhenThereIsAChoice() {
        // Two panels, one taken out.
        XCTAssertEqual(BrightnessController.effectiveExclusions(boostCapable: ["a", "b"], excluded: ["b"]), ["b"])
        // Undocked: the remaining panel was the excluded one. Ignoring the
        // exclusion is what keeps the toggle from doing nothing.
        XCTAssertEqual(BrightnessController.effectiveExclusions(boostCapable: ["b"], excluded: ["b"]), [])
        // Everything excluded is the same dead end.
        XCTAssertEqual(BrightnessController.effectiveExclusions(boostCapable: ["a", "b"], excluded: ["a", "b"]), [])
        // A display that is not attached does not count.
        XCTAssertEqual(BrightnessController.effectiveExclusions(boostCapable: ["a", "b"], excluded: ["zzz"]), [])
    }

    // MARK: - Boost only in chosen apps

    func testAppRule() {
        XCTAssertTrue(BrightnessController.appRuleAllows(frontmost: "com.x", chosen: []))
        XCTAssertTrue(BrightnessController.appRuleAllows(frontmost: nil, chosen: []))
        XCTAssertTrue(BrightnessController.appRuleAllows(frontmost: "com.x", chosen: ["com.x"]))
        XCTAssertFalse(BrightnessController.appRuleAllows(frontmost: "com.y", chosen: ["com.x"]))
        XCTAssertFalse(BrightnessController.appRuleAllows(frontmost: nil, chosen: ["com.x"]))
    }

    // MARK: - Shortcut

    func testShortcutNeedsARealModifier() {
        XCTAssertTrue(Shortcut.isUsable([.command]))
        XCTAssertTrue(Shortcut.isUsable([.control, .shift]))
        // Shift alone would swallow capital letters in every app.
        XCTAssertFalse(Shortcut.isUsable([.shift]))
        XCTAssertFalse(Shortcut.isUsable([]))
    }

    func testShortcutDisplayMatchesTheDefault() {
        let flags: NSEvent.ModifierFlags = [.control, .option, .command]
        XCTAssertEqual(Shortcut.symbols(for: flags) + (Shortcut.keyName(keyCode: 11, characters: "b") ?? ""),
                       Shortcut.standard.display)
        XCTAssertEqual(Shortcut.carbonModifiers(from: flags), Shortcut.standard.carbonModifiers)
        XCTAssertEqual(Shortcut.keyName(keyCode: 49, characters: " "), "Space")
        XCTAssertNil(Shortcut.keyName(keyCode: 200, characters: ""))
    }

    // MARK: - Rating prompt

    private func shouldAsk(paying: Bool = true, boosts: Int = 10, daysAgo: Double = 8,
                           asked: String? = nil, broken: Bool = false) -> Bool {
        let now = Date()
        return ReviewPrompt.shouldAsk(isPaying: paying, boostCount: boosts,
                                      firstBoost: now.addingTimeInterval(-daysAgo * 86_400),
                                      lastAskedVersion: asked, currentVersion: "1.2.0",
                                      boostReportedBroken: broken, now: now)
    }

    func testRatingPromptBar() {
        XCTAssertTrue(shouldAsk())
        XCTAssertFalse(shouldAsk(paying: false))      // trial users have not decided
        XCTAssertFalse(shouldAsk(boosts: 9))
        XCTAssertFalse(shouldAsk(daysAgo: 6))
        XCTAssertFalse(shouldAsk(asked: "1.2.0"))     // once per version
        XCTAssertTrue(shouldAsk(asked: "1.1.9"))
        XCTAssertFalse(shouldAsk(broken: true))       // never where the boost may not work
    }
}
