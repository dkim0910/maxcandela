import XCTest
@testable import MaxCandela

/// The Focus tool's cycle state machine. Times are plain seconds from 0.
final class FocusTests: XCTestCase {
    private let classic = FocusPreset.all[0]

    func testPresets() {
        XCTAssertEqual(FocusPreset.all.map(\.workMinutes), [25, 50, 90])
        XCTAssertEqual(FocusPreset.all.map(\.breakMinutes), [5, 10, 20])
        XCTAssertEqual(FocusPreset.all.map(\.longBreakMinutes), [15, 30, 30])
        XCTAssertEqual(classic.duration(of: .work), 25 * 60)
        XCTAssertEqual(classic.duration(of: .shortBreak), 5 * 60)
        XCTAssertEqual(classic.duration(of: .longBreak), 15 * 60)
        XCTAssertEqual(classic.menuTitle, "25 min Focus · 5 min Break")
    }

    func testWorkThenBreakThenWork() {
        var session = FocusSession(preset: classic, now: 0)
        XCTAssertEqual(session.phase, .work)
        XCTAssertEqual(session.remaining(at: 0), 1500)
        XCTAssertNil(session.advance(at: 1499))
        XCTAssertEqual(session.advance(at: 1500), .shortBreak)
        XCTAssertEqual(session.completedWork, 1)
        XCTAssertEqual(session.remaining(at: 1500), 300)
        XCTAssertEqual(session.advance(at: 1800), .work)
        XCTAssertEqual(session.completedWork, 1, "a break finishing is not a session")
        XCTAssertEqual(session.remaining(at: 1800), 1500)
    }

    func testEveryFourthBreakIsLong() {
        var session = FocusSession(preset: classic, now: 0)
        var phases: [FocusPhase] = [session.phase]
        for step in 1...9 {
            session.skip(at: TimeInterval(step))
            phases.append(session.phase)
        }
        XCTAssertEqual(phases, [.work, .shortBreak, .work, .shortBreak, .work, .shortBreak,
                                .work, .longBreak, .work, .shortBreak])
        XCTAssertEqual(session.completedWork, 5)
        XCTAssertEqual(FocusSession.phase(after: .work, completedWork: 8), .longBreak)
        XCTAssertEqual(FocusSession.phase(after: .work, completedWork: 7), .shortBreak)
        XCTAssertEqual(FocusSession.phase(after: .longBreak, completedWork: 8), .work)
    }

    func testLateTickStartsNextPhaseNowAndNeverCascades() {
        // The Mac slept through the end of a work phase and two hours more.
        var session = FocusSession(preset: classic, now: 0)
        XCTAssertEqual(session.advance(at: 7200), .shortBreak)
        XCTAssertEqual(session.completedWork, 1)
        // A whole break ahead, counted from the moment it was noticed.
        XCTAssertEqual(session.remaining(at: 7200), 300)
        XCTAssertNil(session.advance(at: 7201))
    }

    func testPauseFreezesTheCountdownAndResumeContinuesIt() {
        var session = FocusSession(preset: classic, now: 0)
        session.pause(at: 100)
        XCTAssertTrue(session.isPaused)
        XCTAssertEqual(session.remaining(at: 100), 1400)
        XCTAssertEqual(session.remaining(at: 5000), 1400)
        XCTAssertNil(session.advance(at: 99_999), "a paused phase never ends")
        session.pause(at: 6000)   // second pause is a no-op
        XCTAssertEqual(session.remaining(at: 6000), 1400)
        session.resume(at: 10_000)
        XCTAssertFalse(session.isPaused)
        XCTAssertEqual(session.remaining(at: 10_000), 1400)
        XCTAssertEqual(session.advance(at: 11_400), .shortBreak)
    }

    func testSkipCountsTheWorkSessionAndRunsTheNextPhase() {
        var session = FocusSession(preset: classic, now: 0)
        session.pause(at: 60)
        session.skip(at: 100)
        XCTAssertEqual(session.phase, .shortBreak)
        XCTAssertEqual(session.completedWork, 1)
        XCTAssertFalse(session.isPaused, "skipping is an explicit 'move on'")
        XCTAssertEqual(session.remaining(at: 100), 300)
    }

    func testMenuAndStatusText() {
        var session = FocusSession(preset: classic, now: 0)
        XCTAssertEqual(session.statusText(at: 0), "Focus 25:00")
        XCTAssertEqual(session.menuTitle(at: 0), "Focus — 25:00")
        XCTAssertEqual(session.progressText(at: 1), "Focus 1 of 4 — 24:59 left")
        session.skip(at: 0)
        XCTAssertEqual(session.statusText(at: 0), "Break 5:00")
        XCTAssertEqual(session.progressText(at: 0), "Break — 5:00 left")
        XCTAssertEqual(session.menuTitle(at: 0), "Focus — break 5:00")
        XCTAssertEqual(session.sessionInSet, 1, "the break follows session 1")
        session.skip(at: 0)
        XCTAssertEqual(session.progressText(at: 0), "Focus 2 of 4 — 25:00 left")
        for _ in 0..<5 { session.skip(at: 0) }
        XCTAssertEqual(session.phase, .longBreak)
        XCTAssertEqual(session.sessionInSet, 4)
        XCTAssertEqual(session.progressText(at: 0), "Long break — 15:00 left")
        session.skip(at: 0)
        XCTAssertEqual(session.progressText(at: 0), "Focus 1 of 4 — 25:00 left", "a new set of four")
        session.pause(at: 60)
        XCTAssertEqual(session.statusText(at: 500), "Paused 24:00")
        XCTAssertEqual(session.menuTitle(at: 500), "Focus — 24:00 (paused)")
        XCTAssertEqual(session.progressText(at: 500), "Focus 1 of 4 — 24:00 left (paused)")
    }
}
