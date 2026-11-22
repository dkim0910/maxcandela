import XCTest
@testable import MaxCandela

/// The coordinate maths behind every screen capture. Four coordinate systems
/// meet here (see `ScreenCapture`), and a mix-up between them does not crash
/// — it quietly captures the wrong part of the wrong display, which no one
/// notices on a single-display, single-scale dev Mac. These pin each
/// conversion down on the layouts where they differ.
final class ScreenCaptureTests: XCTestCase {

    // MARK: - Selection → sourceRect

    func testCaptureRectOnADisplayLeftOfAndBelowTheMainOne() {
        // An external display to the left of the laptop, its bottom 300 pt
        // lower: negative AppKit x and y.
        let screen = CGRect(x: -2560, y: -300, width: 2560, height: 1440)       // top edge at y 1140
        let selection = CGRect(x: -2460, y: 1000, width: 200, height: 100)      // top edge at y 1100
        XCTAssertEqual(ScreenCapture.captureRect(selection: selection, screenFrame: screen),
                       CGRect(x: 100, y: 40, width: 200, height: 100))
    }

    func testCaptureRectIsClippedToItsDisplay() {
        // A drag runs past the right edge (onto the next display) and past
        // the top: only the part on this display can be captured.
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let selection = CGRect(x: 1412, y: 900, width: 200, height: 200)
        XCTAssertEqual(ScreenCapture.captureRect(selection: selection, screenFrame: screen),
                       CGRect(x: 1412, y: 0, width: 100, height: 82))
        // Nothing on this display at all.
        XCTAssertEqual(ScreenCapture.captureRect(selection: CGRect(x: 3000, y: 10, width: 50, height: 50),
                                                 screenFrame: screen), .zero)
    }

    // MARK: - Points → pixels

    func testPixelAlignmentGrowsOutwardToWholePixels() {
        let rect = CGRect(x: 10.25, y: 20.75, width: 100.3, height: 50.1)
        // Retina: half points are whole pixels.
        let retina = ScreenCapture.pixelAligned(rect, scale: 2)
        XCTAssertEqual(retina, CGRect(x: 10, y: 20.5, width: 101, height: 50.5))
        XCTAssertTrue(retina.contains(rect))
        XCTAssertEqual(ScreenCapture.pixelSize(of: retina, scale: 2).width, 202)
        XCTAssertEqual(ScreenCapture.pixelSize(of: retina, scale: 2).height, 101)
        // Standard display: whole points.
        XCTAssertEqual(ScreenCapture.pixelAligned(rect, scale: 1), CGRect(x: 10, y: 20, width: 101, height: 51))
    }

    func testPixelSizeKeepsTheLastColumn() {
        // 100.5 pt at 2× is exactly 201 px; truncating would lose one.
        let size = ScreenCapture.pixelSize(of: CGRect(x: 0, y: 0, width: 100.5, height: 10), scale: 2)
        XCTAssertEqual(size.width, 201)
        XCTAssertEqual(size.height, 20)
        // An already aligned rect is left alone.
        let aligned = CGRect(x: 4, y: 8, width: 300, height: 200)
        XCTAssertEqual(ScreenCapture.pixelAligned(aligned, scale: 2), aligned)
    }

    // MARK: - Which screen

    func testScreenUnderThePointerCountsTheTopEdge() {
        let main = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let above = CGRect(x: 0, y: 982, width: 1920, height: 1080)
        // The pointer pushed against the top of the upper display reports
        // y == maxY, which a half-open contains() puts on no screen.
        XCTAssertEqual(ScreenCapture.screenIndex(containing: CGPoint(x: 100, y: 2062), in: [main, above]), 1)
        XCTAssertEqual(ScreenCapture.screenIndex(containing: CGPoint(x: 100, y: 982), in: [main]), 0)
        // On the shared edge, the display it is actually on (the upper one's bottom row).
        XCTAssertEqual(ScreenCapture.screenIndex(containing: CGPoint(x: 100, y: 982), in: [main, above]), 1)
        XCTAssertEqual(ScreenCapture.screenIndex(containing: CGPoint(x: 700, y: 400), in: [main, above]), 0)
        // In the gap beside the smaller display.
        XCTAssertNil(ScreenCapture.screenIndex(containing: CGPoint(x: 1700, y: 100), in: [main, above]))
    }

    // MARK: - AppKit ↔ CoreGraphics global

    func testWindowFramesFlipAgainstThePrimaryDisplay() {
        // Primary display 982 pt tall. A window 50 pt below its top edge.
        XCTAssertEqual(ScreenCapture.appKitRect(fromCG: CGRect(x: 100, y: 50, width: 400, height: 300), primaryHeight: 982),
                       CGRect(x: 100, y: 632, width: 400, height: 300))
        // A window on a display arranged above the primary has a negative CG y.
        XCTAssertEqual(ScreenCapture.appKitRect(fromCG: CGRect(x: 0, y: -1000, width: 400, height: 300), primaryHeight: 982),
                       CGRect(x: 0, y: 1682, width: 400, height: 300))
        XCTAssertEqual(ScreenCapture.cgPoint(fromAppKit: CGPoint(x: -300, y: 1500), primaryHeight: 982),
                       CGPoint(x: -300, y: -518))
    }

    func testAPointInsideAWindowIsInsideItInBothSystems() {
        let primaryHeight: CGFloat = 1117
        let cgFrame = CGRect(x: -1800, y: -600, width: 900, height: 700)   // on a display up and to the left
        let appKitFrame = ScreenCapture.appKitRect(fromCG: cgFrame, primaryHeight: primaryHeight)
        for appKitPoint in [CGPoint(x: appKitFrame.midX, y: appKitFrame.midY),
                            CGPoint(x: appKitFrame.minX + 1, y: appKitFrame.maxY - 1),
                            CGPoint(x: appKitFrame.maxX - 1, y: appKitFrame.minY + 1)] {
            XCTAssertTrue(cgFrame.contains(ScreenCapture.cgPoint(fromAppKit: appKitPoint, primaryHeight: primaryHeight)))
        }
        XCTAssertFalse(cgFrame.contains(ScreenCapture.cgPoint(fromAppKit: CGPoint(x: appKitFrame.midX, y: appKitFrame.maxY + 5),
                                                              primaryHeight: primaryHeight)))
    }

    // MARK: - Picking a window

    private func entry(_ number: Int, pid: Int = 500, layer: Int = 0, alpha: Double = 1,
                       frame: CGRect) -> [String: Any] {
        [kCGWindowNumber as String: number,
         kCGWindowOwnerPID as String: pid,
         kCGWindowLayer as String: layer,
         kCGWindowAlpha as String: alpha,
         kCGWindowBounds as String: frame.dictionaryRepresentation]
    }

    func testOnlyOtherAppsOrdinaryWindowsArePickable() {
        let frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        let info = [
            entry(1, pid: 42, frame: frame),                                  // ours (the overlay, an editor)
            entry(2, layer: Int(CGWindowLevelForKey(.statusWindow)), frame: frame), // a status item
            entry(3, layer: Int(CGWindowLevelForKey(.dockWindow)), frame: frame),   // the Dock
            entry(4, alpha: 0, frame: frame),                                 // invisible
            entry(5, frame: CGRect(x: 0, y: 0, width: 10, height: 10)),       // a sliver
            entry(7, frame: frame),                                           // front window
            entry(8, layer: Int(CGWindowLevelForKey(.floatingWindow)), frame: frame), // a floating panel
            entry(9, frame: frame.offsetBy(dx: 100, dy: 100)),                // behind
        ]
        XCTAssertEqual(ScreenCapture.pickableWindows(from: info, excludingPID: 42).map(\.id), [7, 8, 9])
    }

    func testTheFrontmostWindowUnderThePointerWins() {
        let front = PickableWindow(id: 1, frame: CGRect(x: 0, y: 0, width: 500, height: 500))
        let back = PickableWindow(id: 2, frame: CGRect(x: 100, y: 100, width: 800, height: 800))
        XCTAssertEqual(ScreenCapture.frontmost(at: CGPoint(x: 200, y: 200), in: [front, back]), front)
        XCTAssertEqual(ScreenCapture.frontmost(at: CGPoint(x: 700, y: 700), in: [front, back]), back)
        XCTAssertNil(ScreenCapture.frontmost(at: CGPoint(x: 2000, y: 2000), in: [front, back]))
    }
}
