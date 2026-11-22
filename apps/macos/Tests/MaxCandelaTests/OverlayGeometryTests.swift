import XCTest
import AppKit
@testable import MaxCandela

/// The overlay tools' shared rules: where their windows sit in the window
/// stack, and the conversion between the window server's coordinates and
/// AppKit's across several displays.
final class OverlayGeometryTests: XCTestCase {

    // MARK: - Levels

    func testDesktopLevelIsAboveTheIconsAndBelowEveryAppWindow() {
        let icons = Int(CGWindowLevelForKey(.desktopIconWindow))
        let desktop = Int(CGWindowLevelForKey(.desktopWindow))
        XCTAssertGreaterThan(OverlayLevel.desktop.rawValue, icons)
        XCTAssertGreaterThan(OverlayLevel.desktop.rawValue, desktop)
        XCTAssertLessThan(OverlayLevel.desktop.rawValue, NSWindow.Level.normal.rawValue)
    }

    func testDimmerIsAboveNormalWindowsAndBelowEverythingAppsShowOutsideThem() {
        let dimmer = OverlayLevel.dimmer.rawValue
        XCTAssertGreaterThan(dimmer, NSWindow.Level.normal.rawValue)
        // Floating palettes, alerts, the Dock, the menu bar, menus: never dimmed.
        for above: NSWindow.Level in [.floating, .modalPanel, .mainMenu, .statusBar, .popUpMenu] {
            XCTAssertLessThan(dimmer, above.rawValue)
        }
        XCTAssertLessThan(dimmer, Int(CGWindowLevelForKey(.dockWindow)))
    }

    func testOverlaysStayBelowTheEDRTrigger() {
        // A dark layer over the trigger patch would dim the EDR pixels that
        // keep the panel in HDR mode.
        XCTAssertLessThan(OverlayLevel.dimmer.rawValue, EDROverlayWindow.windowLevel.rawValue)
        XCTAssertLessThan(OverlayLevel.desktop.rawValue, EDROverlayWindow.windowLevel.rawValue)
    }

    // MARK: - Coordinates

    func testQuartzToAppKitOnThePrimaryDisplay() {
        // 1512×982 primary. A window 100 pt from the top, 50 tall.
        let quartz = CGRect(x: 20, y: 100, width: 300, height: 50)
        let appKit = ScreenGeometry.appKitRect(fromQuartz: quartz, primaryScreenHeight: 982)
        XCTAssertEqual(appKit, CGRect(x: 20, y: 832, width: 300, height: 50))
    }

    func testQuartzToAppKitOnADisplayAboveThePrimary() {
        // A 1920×1080 display arranged above a 1512×982 primary: AppKit
        // frame (0, 982, 1920, 1080); Quartz origin (0, −1080).
        let screen = CGRect(x: 0, y: 982, width: 1920, height: 1080)
        let quartz = CGRect(x: 0, y: -1080, width: 1920, height: 1080)   // covers it exactly
        XCTAssertEqual(ScreenGeometry.appKitRect(fromQuartz: quartz, primaryScreenHeight: 982), screen)
        let window = CGRect(x: 100, y: -1000, width: 400, height: 300)    // 80 pt below its top
        let converted = ScreenGeometry.appKitRect(fromQuartz: window, primaryScreenHeight: 982)
        XCTAssertEqual(converted, CGRect(x: 100, y: 1682, width: 400, height: 300))
        XCTAssertEqual(ScreenGeometry.local(converted, in: screen), CGRect(x: 100, y: 700, width: 400, height: 300))
    }

    func testQuartzToAppKitOnADisplayLeftOfAndBelowThePrimary() {
        // A 1440×900 display to the left, its top 500 pt below the primary's
        // top: Quartz origin (−1440, 500), AppKit frame (−1440, 982−500−900).
        let screen = CGRect(x: -1440, y: -418, width: 1440, height: 900)
        let quartz = CGRect(x: -1440, y: 500, width: 1440, height: 900)
        XCTAssertEqual(ScreenGeometry.appKitRect(fromQuartz: quartz, primaryScreenHeight: 982), screen)
        let window = CGRect(x: -1400, y: 520, width: 200, height: 100)
        let local = ScreenGeometry.local(
            ScreenGeometry.appKitRect(fromQuartz: window, primaryScreenHeight: 982), in: screen)
        // 40 pt in from its left edge, 20 pt down from its top.
        XCTAssertEqual(local, CGRect(x: 40, y: 900 - 20 - 100, width: 200, height: 100))
    }

    func testPrimaryIsTheScreenAtTheOrigin() {
        let external = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        let builtIn = CGRect(x: 0, y: 0, width: 1512, height: 982)
        XCTAssertEqual(ScreenGeometry.primaryScreenHeight([external, builtIn]), 982)
        XCTAssertEqual(ScreenGeometry.primaryScreenHeight([builtIn, external]), 982)
        XCTAssertNil(ScreenGeometry.primaryScreenHeight([]))
    }
}
