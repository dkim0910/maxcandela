import AppKit
import XCTest
@testable import MaxCandela

/// The Breaks tool's screen-time clock and the reminder panel's placement.
/// Times are plain seconds from 0; the interval is 20 minutes unless stated.
final class BreaksTests: XCTestCase {
    private func clock(interval: TimeInterval = 1200) -> BreakClock {
        BreakClock(interval: interval, now: 0)
    }

    func testCountsScreenTimeAndRemindsAtTheInterval() {
        let clock = clock()
        XCTAssertEqual(clock.used(at: 600), 600)
        XCTAssertEqual(clock.remaining(at: 600), 600)
        XCTAssertFalse(clock.shouldRemind(at: 1199))
        XCTAssertTrue(clock.shouldRemind(at: 1200))
        XCTAssertEqual(clock.remaining(at: 5000), 0)
    }

    func testShortAbsencePausesTheCountWithoutResettingIt() {
        var clock = clock()
        clock.away(.locked, at: 100)
        XCTAssertTrue(clock.isAway)
        XCTAssertEqual(clock.used(at: 110), 100, "time away is not screen time")
        clock.back(.locked, at: 110)   // 10 s: shorter than a break
        XCTAssertFalse(clock.isAway)
        XCTAssertEqual(clock.used(at: 120), 110)
    }

    func testAbsenceAsLongAsTheBreakIsTheBreak() {
        var clock = clock()
        clock.away(.screenSaver, at: 1000)
        clock.back(.screenSaver, at: 1000 + BreakClock.breakLength)
        XCTAssertEqual(clock.used(at: 1030), 10)
    }

    func testOverlappingReasonsEndOnlyWhenTheLastOneDoes() {
        var clock = clock()
        clock.away(.locked, at: 100)
        clock.away(.displayAsleep, at: 130)
        clock.back(.displayAsleep, at: 500)   // display on, still at the lock screen
        XCTAssertTrue(clock.isAway)
        XCTAssertEqual(clock.used(at: 505), 100)
        clock.back(.locked, at: 510)
        XCTAssertFalse(clock.isAway)
        // Measured from the lock, the first sign of leaving: 410 s, a break.
        XCTAssertEqual(clock.used(at: 520), 10)
    }

    func testBackWithoutMatchingAwayIsIgnored() {
        var clock = clock()
        clock.back(.screenSaver, at: 100)
        XCTAssertEqual(clock.used(at: 200), 200)
        clock.away(.locked, at: 300)
        clock.back(.screenSaver, at: 400)
        XCTAssertTrue(clock.isAway, "an unrelated 'back' must not end the lock")
    }

    func testNoReminderWhileAwayEvenIfDue() {
        var clock = clock(interval: 60)
        clock.away(.displayAsleep, at: 65)
        XCTAssertFalse(clock.shouldRemind(at: 70))
        clock.back(.displayAsleep, at: 70)   // 5 s away: not a break
        XCTAssertTrue(clock.shouldRemind(at: 70), "still owed, now that they're back")
    }

    func testWakeEndsEveryAbsence() {
        var clock = clock()
        clock.away(.locked, at: 100)
        clock.away(.asleep, at: 110)
        clock.woke(at: 3700)
        XCTAssertFalse(clock.isAway)
        XCTAssertEqual(clock.used(at: 3710), 10)
    }

    func testWakeWithoutHearingTheSleepStillCountsAsABreak() {
        var clock = clock()
        clock.woke(at: 900)
        XCTAssertEqual(clock.used(at: 910), 10)
    }

    func testRestartKeepsAnAbsenceInProgress() {
        // The reminder finishes while the user is at the lock screen.
        var clock = clock()
        clock.away(.locked, at: 1190)
        clock.restart(at: 1200)
        XCTAssertTrue(clock.isAway)
        XCTAssertEqual(clock.used(at: 1205), 0)
        clock.back(.locked, at: 1200)   // 10 s: not itself a break
        XCTAssertFalse(clock.isAway, "the return must still end the absence")
        XCTAssertEqual(clock.used(at: 1260), 60)
    }

    func testSnoozeRemindsAfterThatMuchMoreScreenTime() {
        var clock = clock()
        XCTAssertTrue(clock.shouldRemind(at: 1200))
        clock.snooze(for: 300, at: 1200)
        XCTAssertEqual(clock.remaining(at: 1200), 300)
        XCTAssertFalse(clock.shouldRemind(at: 1499))
        XCTAssertTrue(clock.shouldRemind(at: 1500))
    }

    func testBackFromEverythingRecoversAStuckAbsence() {
        var clock = clock()
        clock.away(.locked, at: 100)
        clock.away(.screenSaver, at: 200)
        clock.backFromEverything(at: 5000)
        XCTAssertFalse(clock.isAway)
        XCTAssertEqual(clock.used(at: 5010), 10)
    }

    func testClockSetBackwardsNeverSubtracts() {
        let clock = BreakClock(interval: 1200, now: 1000)
        XCTAssertEqual(clock.used(at: 900), 0)
    }

    func testChangingTheIntervalKeepsTheCount() {
        var clock = clock()
        clock.interval = 300
        XCTAssertTrue(clock.shouldRemind(at: 400))
    }

    func testNextBreakText() {
        XCTAssertEqual(BreaksTool.nextBreakText(remaining: 720, away: false), "Next break in 12 min")
        XCTAssertEqual(BreaksTool.nextBreakText(remaining: 61, away: false), "Next break in 2 min")
        XCTAssertEqual(BreaksTool.nextBreakText(remaining: 59, away: false), "Next break in under a minute")
        XCTAssertEqual(BreaksTool.nextBreakText(remaining: 600, away: true), "Paused while you’re away")
    }

    // MARK: - Reminder panel

    func testPanelSitsCentredUnderTheMenuBar() {
        let size = NSSize(width: 380, height: 90)
        let primary = NSRect(x: 0, y: 0, width: 1512, height: 944)   // visible frame
        XCTAssertEqual(BreakPanel.origin(for: size, in: primary), NSPoint(x: 566, y: 842))
        // A second display above-right of the first, in global coordinates.
        let second = NSRect(x: 1512, y: 982, width: 2560, height: 1415)
        XCTAssertEqual(BreakPanel.origin(for: size, in: second), NSPoint(x: 2602, y: 2295))
    }

    func testPanelGoesToTheScreenUnderThePointer() {
        let frames = [NSRect(x: 0, y: 0, width: 1512, height: 982),
                      NSRect(x: 1512, y: 982, width: 2560, height: 1440)]
        XCTAssertEqual(BreakPanel.screenIndex(containing: NSPoint(x: 700, y: 400), in: frames), 0)
        XCTAssertEqual(BreakPanel.screenIndex(containing: NSPoint(x: 2000, y: 1500), in: frames), 1)
        // The pointer parked on the menu bar reports the screen's top edge.
        XCTAssertEqual(BreakPanel.screenIndex(containing: NSPoint(x: 700, y: 982), in: frames), 0)
        XCTAssertNil(BreakPanel.screenIndex(containing: NSPoint(x: -50, y: 400), in: frames))
    }

    func testCountdownText() {
        XCTAssertEqual(BreakPanel.countdownText(seconds: 20), "Closes in 20 s")
        XCTAssertEqual(BreakPanel.countdownText(seconds: -3), "Closes in 0 s")
        XCTAssertEqual(BreakPanel.message, "Time for a break: look at something 20 feet away")
    }
}
