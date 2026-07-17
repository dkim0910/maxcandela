import XCTest
import AppKit
@testable import MaxCandela

/// These tests exercise pure logic that doesn't require a real EDR panel.
/// Anything that actually drives the backlight has to be verified by hand on
/// EDR-capable hardware — see the "Verifying a brightness change" note in
/// CLAUDE.md.
final class DisplayManagerTests: XCTestCase {

    func testDisplayManagerEnumeratesAtLeastOneScreen() {
        // A test host always has the main screen available.
        let manager = DisplayManager()
        XCTAssertFalse(manager.currentDisplays().isEmpty,
                       "Expected at least one attached display in the test environment")
    }

    func testBestPotentialHeadroomIsAtLeastOne() {
        // Headroom is never reported below 1.0 (SDR white). On non-EDR CI
        // machines this should be exactly 1.0.
        let manager = DisplayManager()
        XCTAssertGreaterThanOrEqual(manager.bestPotentialHeadroom(), 1.0)
    }

    func testSupportsBoostReflectsPotentialHeadroom() throws {
        guard let screen = NSScreen.main else {
            throw XCTSkip("No main screen available")
        }
        let noHeadroom = DisplayInfo(screen: screen, currentHeadroom: 1.0, potentialHeadroom: 1.0)
        XCTAssertFalse(noHeadroom.supportsBoost)

        let withHeadroom = DisplayInfo(screen: screen, currentHeadroom: 1.6, potentialHeadroom: 2.0)
        XCTAssertTrue(withHeadroom.supportsBoost)
    }

    func testPreferencesRoundTrip() {
        let suiteName = "com.maxcandela.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let prefs = Preferences(defaults: defaults)
        XCTAssertFalse(prefs.isEnabled)     // default
        XCTAssertEqual(prefs.boost, 1.0)    // default

        prefs.isEnabled = true
        prefs.boost = 1.8
        XCTAssertTrue(prefs.isEnabled)
        XCTAssertEqual(prefs.boost, 1.8, accuracy: 0.0001)
    }
}
