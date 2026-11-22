import XCTest
import AppKit
@testable import MaxCandela

/// Dim Background Windows: reading the window list, deciding what is dark,
/// and turning that into the overlay's path. The rule that matters most is
/// the failure direction — whenever the list cannot be trusted, nothing is
/// dimmed, so the window being worked in is never darkened.
final class WindowDimmerTests: XCTestCase {
    private let front: pid_t = 100
    private let other: pid_t = 200
    private let third: pid_t = 300
    private let helper: pid_t = 900     // an XPC service, a menu-bar app
    private let primaryHeight: CGFloat = 1000
    private let screen = CGRect(x: 0, y: 0, width: 1600, height: 1000)

    private func entry(pid: pid_t?, layer: Int?, bounds: CGRect?, alpha: Double? = nil) -> [String: Any] {
        var dict: [String: Any] = [:]
        if let pid { dict[kCGWindowOwnerPID as String] = NSNumber(value: pid) }
        if let layer { dict[kCGWindowLayer as String] = NSNumber(value: layer) }
        if let bounds { dict[kCGWindowBounds as String] = bounds.dictionaryRepresentation as NSDictionary }
        if let alpha { dict[kCGWindowAlpha as String] = NSNumber(value: alpha) }
        return dict
    }

    private func window(_ pid: pid_t, _ rect: CGRect) -> WindowRecord {
        WindowRecord(pid: pid, layer: 0, bounds: rect, alpha: 1)
    }

    /// Windows front to back, in Quartz coordinates (y down from the top).
    private func plan(_ windows: [WindowRecord], front: pid_t? = 100) -> DimmerModel.Plan {
        DimmerModel.plan(reading: .windows(windows), frontPID: front,
                         dimmablePIDs: [self.front, other, third], primaryScreenHeight: primaryHeight)
    }

    private func steps(_ plan: DimmerModel.Plan, file: StaticString = #filePath, line: UInt = #line) -> [DimmerModel.Step] {
        guard case .paint(let steps) = plan else {
            XCTFail("expected a paint plan, got \(plan)", file: file, line: line)
            return []
        }
        return steps
    }

    /// A point given in Quartz coordinates, for readable assertions.
    private func dimmed(_ x: CGFloat, _ y: CGFloat, _ steps: [DimmerModel.Step]) -> Bool {
        DimmerModel.isDimmed(CGPoint(x: x, y: primaryHeight - y), steps: steps)
    }

    // MARK: - Reading

    func testReadKeepsNormalWindowsInOrderAndSkipsOtherLayers() {
        let list = [
            entry(pid: 1, layer: 25, bounds: nil),                       // status item: no bounds needed
            entry(pid: front, layer: 0, bounds: CGRect(x: 0, y: 0, width: 10, height: 10)),
            entry(pid: other, layer: 0, bounds: CGRect(x: 5, y: 5, width: 10, height: 10), alpha: 0.5),
        ]
        XCTAssertEqual(DimmerModel.read(list), .windows([
            WindowRecord(pid: front, layer: 0, bounds: CGRect(x: 0, y: 0, width: 10, height: 10), alpha: 1),
            WindowRecord(pid: other, layer: 0, bounds: CGRect(x: 5, y: 5, width: 10, height: 10), alpha: 0.5),
        ]))
    }

    func testMissingBoundsOwnerOrLayerMakesTheListUnreadable() {
        let ok = entry(pid: front, layer: 0, bounds: CGRect(x: 0, y: 0, width: 10, height: 10))
        XCTAssertEqual(DimmerModel.read(nil), .unreadable)
        XCTAssertEqual(DimmerModel.read([ok, entry(pid: other, layer: 0, bounds: nil)]), .unreadable)
        XCTAssertEqual(DimmerModel.read([ok, entry(pid: nil, layer: 0, bounds: .zero)]), .unreadable)
        XCTAssertEqual(DimmerModel.read([ok, entry(pid: other, layer: nil, bounds: .zero)]), .unreadable)
        XCTAssertEqual(DimmerModel.read([]), .windows([]))
    }

    // MARK: - Failing safe

    func testUnreadableListDimsNothing() {
        let plan = DimmerModel.plan(reading: .unreadable, frontPID: front, dimmablePIDs: [front, other],
                                    primaryScreenHeight: primaryHeight)
        XCTAssertEqual(plan, .dimNothing(.unreadable))
    }

    func testNoFrontAppDimsNothing() {
        XCTAssertEqual(plan([window(other, screen)], front: nil), .dimNothing(.noFrontApp))
    }

    func testFrontAppWithoutAVisibleWindowDimsNothing() {
        // Only the desktop (Finder with no windows), or bounds withheld as
        // zero rects: never dim everything else into a dark slab.
        XCTAssertEqual(plan([window(other, CGRect(x: 0, y: 0, width: 500, height: 500))]),
                       .dimNothing(.frontAppHasNoWindows))
        XCTAssertEqual(plan([window(front, .zero), window(other, CGRect(x: 0, y: 0, width: 500, height: 500))]),
                       .dimNothing(.frontAppHasNoWindows))
        let invisible = WindowRecord(pid: front, layer: 0, bounds: CGRect(x: 0, y: 0, width: 500, height: 500), alpha: 0)
        XCTAssertEqual(plan([invisible]), .dimNothing(.frontAppHasNoWindows))
    }

    // MARK: - What is dark

    func testFrontWindowIsClearAndEverythingElseIsDark() {
        let steps = steps(plan([
            window(front, CGRect(x: 100, y: 100, width: 400, height: 300)),
            window(other, CGRect(x: 600, y: 100, width: 400, height: 300)),
        ]))
        XCTAssertFalse(dimmed(150, 150, steps))     // in the front window
        XCTAssertTrue(dimmed(650, 150, steps))      // in the background window
        XCTAssertTrue(dimmed(1500, 900, steps))     // the desktop
    }

    func testABackgroundWindowInFrontOfTheFrontAppStaysDark() {
        // Clicking one window of an app brings only that window forward, so
        // another app's window can sit over a second window of the front app.
        let steps = steps(plan([
            window(front, CGRect(x: 0, y: 0, width: 200, height: 200)),        // frontmost
            window(other, CGRect(x: 250, y: 250, width: 300, height: 300)),     // over the next one
            window(front, CGRect(x: 300, y: 300, width: 400, height: 400)),
        ]))
        XCTAssertFalse(dimmed(100, 100, steps))
        XCTAssertTrue(dimmed(400, 400, steps))      // overlap: the other app's window is on top
        XCTAssertFalse(dimmed(650, 650, steps))     // rest of the front app's back window
    }

    func testTheFrontAppOnTopOfABackgroundWindowIsClear() {
        let steps = steps(plan([
            window(front, CGRect(x: 300, y: 300, width: 400, height: 400)),
            window(other, CGRect(x: 250, y: 250, width: 300, height: 300)),
        ]))
        XCTAssertFalse(dimmed(400, 400, steps))
        XCTAssertTrue(dimmed(260, 260, steps))
    }

    func testHelperProcessWindowsAreNeverDimmed() {
        // A sandboxed app's Open/Save sheet is owned by an XPC service.
        let steps = steps(plan([
            window(helper, CGRect(x: 150, y: 100, width: 300, height: 200)),
            window(front, CGRect(x: 100, y: 80, width: 400, height: 400)),
        ]))
        XCTAssertFalse(dimmed(200, 150, steps))
        XCTAssertFalse(dimmed(120, 450, steps))
    }

    func testDimStepsBehindEverythingAreDropped() {
        let steps = steps(plan([
            window(front, CGRect(x: 0, y: 0, width: 100, height: 100)),
            window(other, CGRect(x: 500, y: 500, width: 100, height: 100)),
            window(third, CGRect(x: 700, y: 500, width: 100, height: 100)),
        ]))
        XCTAssertEqual(steps.count, 1)
        XCTAssertEqual(steps.first?.dim, false)
    }

    // MARK: - The overlay path matches the model

    func testPathAgreesWithTheModelAcrossTheScreen() {
        let scenarios: [[WindowRecord]] = [
            [window(front, CGRect(x: 100, y: 100, width: 400, height: 300))],
            [window(front, CGRect(x: 0, y: 0, width: 200, height: 200)),
             window(other, CGRect(x: 150, y: 150, width: 300, height: 300)),
             window(front, CGRect(x: 300, y: 300, width: 600, height: 500)),
             window(third, CGRect(x: 800, y: 0, width: 600, height: 900))],
            [window(helper, CGRect(x: 0, y: 0, width: 1600, height: 1000)),
             window(front, CGRect(x: 400, y: 200, width: 400, height: 400))],
        ]
        for windows in scenarios {
            let steps = steps(plan(windows))
            let path = DimmerModel.dimPath(steps: steps, screenFrame: screen)
            for x in stride(from: CGFloat(5), to: 1600, by: 50) {
                for y in stride(from: CGFloat(5), to: 1000, by: 50) {
                    let point = CGPoint(x: x, y: y)
                    XCTAssertEqual(path.contains(point), DimmerModel.isDimmed(point, steps: steps),
                                   "at \(point) for \(windows)")
                }
            }
        }
    }

    func testPathOnASecondDisplayIsLocalToIt() {
        // A display to the right of the primary; the front window is on it.
        let right = CGRect(x: 1600, y: 0, width: 1000, height: 800)
        let steps = steps(plan([window(front, CGRect(x: 1700, y: 300, width: 200, height: 200))]))
        let path = DimmerModel.dimPath(steps: steps, screenFrame: right)
        // Quartz (1800, 400) → AppKit (1800, 600) → local to `right` (200, 600).
        XCTAssertFalse(path.contains(CGPoint(x: 200, y: 600)))
        XCTAssertTrue(path.contains(CGPoint(x: 500, y: 600)))
        // The primary has nothing of the front app: all dark.
        let primaryPath = DimmerModel.dimPath(steps: steps, screenFrame: screen)
        XCTAssertTrue(primaryPath.contains(CGPoint(x: 800, y: 500)))
    }

    func testAFullScreenFrontWindowLeavesNothingToDim() {
        let steps = steps(plan([window(front, CGRect(x: 0, y: 0, width: 1600, height: 1000))]))
        XCTAssertTrue(DimmerModel.dimPath(steps: steps, screenFrame: screen).boundingBoxOfPath.isEmpty)
        let partial = self.steps(plan([window(front, CGRect(x: 0, y: 0, width: 800, height: 1000))]))
        XCTAssertFalse(DimmerModel.dimPath(steps: partial, screenFrame: screen).boundingBoxOfPath.isEmpty)
    }

    // MARK: - Strength and polling

    func testStrengthSpansTenToSeventyPercent() {
        XCTAssertEqual(DimmerModel.opacity(slider: 0), 0.10, accuracy: 1e-9)
        XCTAssertEqual(DimmerModel.opacity(slider: 1), 0.70, accuracy: 1e-9)
        XCTAssertEqual(DimmerModel.opacity(slider: 2), 0.70, accuracy: 1e-9)
        XCTAssertEqual(DimmerModel.slider(opacity: DimmerModel.opacity(slider: 0.25)), 0.25, accuracy: 1e-9)
        XCTAssertEqual(DimmerModel.percentText(opacity: DimmerModel.defaultOpacity), "35%")
        XCTAssertEqual(DimmerModel.percentText(opacity: 0.95), "70%")
    }

    func testPollsFastWhileThingsMoveAndSlowWhenStill() {
        XCTAssertEqual(DimmerModel.pollEvery(secondsSinceChange: 0.5), 1)
        XCTAssertEqual(DimmerModel.pollEvery(secondsSinceChange: 10), 4)
    }
}
