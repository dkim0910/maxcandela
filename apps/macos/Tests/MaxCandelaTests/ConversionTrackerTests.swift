import XCTest
@testable import MaxCandela

/// The subscriber attributes are what RevenueCat customer lists filter on, so
/// the mapping from licence state to attribute strings is pinned here.
final class ConversionTrackerTests: XCTestCase {

    func testTrialCarriesDaysLeft() {
        let attrs = ConversionTracker.attributes(for: .trial(daysRemaining: 3))
        XCTAssertEqual(attrs[ConversionTracker.AttributeKey.licenseState], "trial")
        XCTAssertEqual(attrs[ConversionTracker.AttributeKey.trialDaysLeft], "3")
    }

    func testExpiredReportsZeroDays() {
        let attrs = ConversionTracker.attributes(for: .expired)
        XCTAssertEqual(attrs[ConversionTracker.AttributeKey.licenseState], "expired")
        XCTAssertEqual(attrs[ConversionTracker.AttributeKey.trialDaysLeft], "0")
    }

    /// Once licensed the days-left figure is meaningless; an empty value is
    /// how RevenueCat clears an attribute, so a stale "2" can't linger.
    func testLicensedClearsDaysLeft() {
        let attrs = ConversionTracker.attributes(for: .licensed)
        XCTAssertEqual(attrs[ConversionTracker.AttributeKey.licenseState], "licensed")
        XCTAssertEqual(attrs[ConversionTracker.AttributeKey.trialDaysLeft], "")
    }

    /// Every state must set the same keys — a filter built on one state's
    /// attributes has to work for all of them.
    func testAllStatesSetTheSameKeys() {
        let states: [StoreManager.LicenseState] = [.licensed, .trial(daysRemaining: 5), .expired]
        let keySets = states.map { Set(ConversionTracker.attributes(for: $0).keys) }
        XCTAssertEqual(Set(keySets).count, 1)
    }
}
