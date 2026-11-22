import XCTest
import AppKit
@testable import MaxCandela

/// Desktop tool: laying the wallpaper out the way macOS does, decoding it no
/// larger than needed, and where the notch band goes.
final class DesktopToolTests: XCTestCase {

    // MARK: - Wallpaper layout

    func testGravityFollowsTheDesktopImageOptions() {
        typealias Key = NSWorkspace.DesktopImageOptionKey
        func options(_ scaling: NSImageScaling?, clipping: Bool?) -> [Key: Any] {
            var dict: [Key: Any] = [:]
            if let scaling { dict[.imageScaling] = NSNumber(value: scaling.rawValue) }
            if let clipping { dict[.allowClipping] = NSNumber(value: clipping) }
            return dict
        }
        // Fill Screen / Fit to Screen / Stretch to Fill / Centre.
        XCTAssertEqual(DesktopLayout.gravity(options: options(.scaleProportionallyUpOrDown, clipping: true)), .resizeAspectFill)
        XCTAssertEqual(DesktopLayout.gravity(options: options(.scaleProportionallyUpOrDown, clipping: false)), .resizeAspect)
        XCTAssertEqual(DesktopLayout.gravity(options: options(.scaleAxesIndependently, clipping: true)), .resize)
        XCTAssertEqual(DesktopLayout.gravity(options: options(.scaleNone, clipping: nil)), .center)
        // NSWorkspace.h defaults: no scaling → proportional; no clipping → fit.
        XCTAssertEqual(DesktopLayout.gravity(options: [.fillColor: NSColor.black]), .resizeAspect)
        XCTAssertEqual(DesktopLayout.gravity(options: options(nil, clipping: true)), .resizeAspectFill)
        // "Proportionally down is not currently supported": treated as up-or-down.
        XCTAssertEqual(DesktopLayout.gravity(options: options(.scaleProportionallyDown, clipping: true)), .resizeAspectFill)
        // No options at all — nil, or the empty dictionary macOS 26 returns
        // for a system wallpaper: Fill Screen.
        XCTAssertEqual(DesktopLayout.gravity(options: nil), .resizeAspectFill)
        XCTAssertEqual(DesktopLayout.gravity(options: options(nil, clipping: nil)), .resizeAspectFill)
    }

    func testDecodeSizeCoversTheScreenAndNoMore() {
        let screen = CGSize(width: 3024, height: 1964)        // 14" MacBook Pro, pixels
        let square = CGSize(width: 6016, height: 6016)          // a system wallpaper
        // Fill: the shorter screen side is not the limit — width is.
        XCTAssertEqual(DesktopLayout.decodeMaxPixelSize(image: square, screen: screen, gravity: .resizeAspectFill), 3024)
        XCTAssertEqual(DesktopLayout.decodeMaxPixelSize(image: square, screen: screen, gravity: .resize), 3024)
        // Fit: the height is.
        XCTAssertEqual(DesktopLayout.decodeMaxPixelSize(image: square, screen: screen, gravity: .resizeAspect), 1964)
        // Centre: pixel for pixel.
        XCTAssertEqual(DesktopLayout.decodeMaxPixelSize(image: square, screen: screen, gravity: .center), 6016)
        // Never upsampled: a small image decodes at its own size.
        let small = CGSize(width: 1024, height: 768)
        XCTAssertEqual(DesktopLayout.decodeMaxPixelSize(image: small, screen: screen, gravity: .resizeAspectFill), 1024)
        XCTAssertEqual(DesktopLayout.decodeMaxPixelSize(image: .zero, screen: screen, gravity: .resizeAspectFill), 0)
    }

    func testFillOfAPortraitImageIsLimitedByTheScreenWidth() {
        let screen = CGSize(width: 2000, height: 1000)
        let portrait = CGSize(width: 1000, height: 4000)
        // Width must reach 2000 → scale 2 → capped at 1 → the file's 4000.
        XCTAssertEqual(DesktopLayout.decodeMaxPixelSize(image: portrait, screen: screen, gravity: .resizeAspectFill), 4000)
        // Fit: height 1000 → scale 0.25 → longest side 1000.
        XCTAssertEqual(DesktopLayout.decodeMaxPixelSize(image: portrait, screen: screen, gravity: .resizeAspect), 1000)
    }

    func testUnknownSavedStyleFallsBackToWallpaper() {
        XCTAssertEqual(DesktopTool.CurtainStyle.saved(nil), .wallpaper)
        XCTAssertEqual(DesktopTool.CurtainStyle.saved("plaid"), .wallpaper)
        XCTAssertEqual(DesktopTool.CurtainStyle.saved("black"), .black)
        XCTAssertNil(DesktopTool.CurtainStyle.wallpaper.color)
        XCTAssertNotNil(DesktopTool.CurtainStyle.graphite.color)
    }

    // MARK: - Window and notch band

    func testWindowCoversTheScreenOnlyForTheCurtain() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let band = CGRect(x: 0, y: 944, width: 1512, height: 38)
        XCTAssertEqual(DesktopLayout.windowFrame(screenFrame: screen, curtain: true, band: band), screen)
        XCTAssertEqual(DesktopLayout.windowFrame(screenFrame: screen, curtain: true, band: nil), screen)
        XCTAssertEqual(DesktopLayout.windowFrame(screenFrame: screen, curtain: false, band: band), band)
        XCTAssertNil(DesktopLayout.windowFrame(screenFrame: screen, curtain: false, band: nil))
    }

    func testCameraHousingDetection() {
        XCTAssertTrue(DesktopLayout.hasCameraHousing(safeAreaTop: 38, auxiliaryLeft: nil, auxiliaryRight: nil))
        XCTAssertTrue(DesktopLayout.hasCameraHousing(
            safeAreaTop: 0, auxiliaryLeft: CGRect(x: 0, y: 944, width: 660, height: 38), auxiliaryRight: nil))
        XCTAssertFalse(DesktopLayout.hasCameraHousing(safeAreaTop: 0, auxiliaryLeft: nil, auxiliaryRight: nil))
        XCTAssertFalse(DesktopLayout.hasCameraHousing(safeAreaTop: 0, auxiliaryLeft: .zero, auxiliaryRight: .zero))
    }

    func testBandSpansTheTopOfItsScreen() {
        // Built-in display as primary: 1512×982, menu bar 38 tall (visible
        // frame ends at 944; the Dock takes the bottom 70).
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let visible = CGRect(x: 0, y: 70, width: 1512, height: 874)
        XCTAssertEqual(DesktopLayout.bandRect(screenFrame: screen, visibleFrame: visible, safeAreaTop: 32),
                       CGRect(x: 0, y: 944, width: 1512, height: 38))
        // Menu bar set to hide: the housing's own height is used.
        XCTAssertEqual(DesktopLayout.bandRect(screenFrame: screen, visibleFrame: screen, safeAreaTop: 32),
                       CGRect(x: 0, y: 950, width: 1512, height: 32))
        XCTAssertNil(DesktopLayout.bandRect(screenFrame: screen, visibleFrame: screen, safeAreaTop: 0))
    }

    func testBandOnThe16InchPanelAsMeasured() {
        // M1 Pro 16", macOS 26.6 (2026-11-22): the menu bar is 33 pt, one
        // more than the 32 pt safe-area inset — the band takes the taller.
        let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)
        let visible = CGRect(x: 0, y: 59, width: 1728, height: 1025)
        XCTAssertEqual(DesktopLayout.bandRect(screenFrame: screen, visibleFrame: visible, safeAreaTop: 32),
                       CGRect(x: 0, y: 1084, width: 1728, height: 33))
        XCTAssertTrue(DesktopLayout.hasCameraHousing(
            safeAreaTop: 32, auxiliaryLeft: CGRect(x: 0, y: 1085, width: 771, height: 32), auxiliaryRight: nil))
    }

    func testBandOnABuiltInDisplayThatIsNotPrimary() {
        // Built-in to the right of an external primary, lower edges aligned.
        let screen = CGRect(x: 1920, y: 0, width: 1512, height: 982)
        let visible = CGRect(x: 1920, y: 0, width: 1512, height: 944)
        let band = DesktopLayout.bandRect(screenFrame: screen, visibleFrame: visible, safeAreaTop: 38)
        XCTAssertEqual(band, CGRect(x: 1920, y: 944, width: 1512, height: 38))
        // In a band-only window the band layer fills it; in a curtain window
        // it sits at the top.
        XCTAssertEqual(band.map { ScreenGeometry.local($0, in: $0) }, CGRect(x: 0, y: 0, width: 1512, height: 38))
        XCTAssertEqual(band.map { ScreenGeometry.local($0, in: screen) }, CGRect(x: 0, y: 944, width: 1512, height: 38))
    }

    func testBandIsOnlyDrawnUnderLightMenuBarText() {
        XCTAssertTrue(DesktopLayout.menuBarDrawsLightText(NSAppearance(named: .darkAqua)))
        XCTAssertTrue(DesktopLayout.menuBarDrawsLightText(NSAppearance(named: .vibrantDark)))
        XCTAssertFalse(DesktopLayout.menuBarDrawsLightText(NSAppearance(named: .aqua)))
        XCTAssertFalse(DesktopLayout.menuBarDrawsLightText(NSAppearance(named: .vibrantLight)))
        // Unknown: black under text of unknown colour could hide the menu bar.
        XCTAssertFalse(DesktopLayout.menuBarDrawsLightText(nil))
    }
}
