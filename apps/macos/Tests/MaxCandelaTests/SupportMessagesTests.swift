import XCTest
@testable import MaxCandela

/// Guards the copy shown to users whose display can't be boosted.
///
/// App Review rejected 1.0.4 after testing on a MacBook Air M3. These tests
/// pin the two mistakes that caused (or would repeat) that outcome: naming a
/// chip generation instead of a display, and failing to say which Macs are
/// excluded.
final class SupportMessagesTests: XCTestCase {

    /// The message must name the actual supported machines, not just say
    /// "unsupported display" and leave the user guessing what to buy.
    func testNoHeadroomBodyNamesSupportedHardware() {
        let body = SupportMessages.noHeadroomBody
        XCTAssertTrue(body.contains("MacBook Pro"),
                      "Must name the MacBook Pro as the supported machine")
        XCTAssertTrue(body.contains("14″") && body.contains("16″"),
                      "Must name both supported MacBook Pro sizes")
        XCTAssertTrue(body.contains("Pro Display XDR"),
                      "Pro Display XDR is supported and must be listed")
    }

    /// The rejection case: someone on a MacBook Air must be told *their* Mac
    /// is the reason, otherwise the app reads as broken.
    func testNoHeadroomBodyCallsOutUnsupportedMacs() {
        let body = SupportMessages.noHeadroomBody
        XCTAssertTrue(body.contains("MacBook Air"),
                      "MacBook Air is the most common unsupported Mac and must be named")
        XCTAssertTrue(body.lowercased().contains("nothing is wrong with your Mac".lowercased()),
                      "Must reassure the user their Mac isn't faulty")
    }

    /// "M1 or newer" is the trap: an M1 MacBook Air satisfies it and still
    /// can't boost. Any chip mention must be qualified with M1 Pro / M1 Max.
    func testChipWordingIsNotMisleading() {
        let text = SupportMessages.supportedHardware + SupportMessages.noHeadroomBody
        if text.contains("M1") {
            XCTAssertTrue(text.contains("M1 Pro") || text.contains("M1 Max"),
                          "A bare 'M1' claim wrongly includes the MacBook Air — qualify it with M1 Pro/Max")
        }
    }

    /// The menu line has to fit a status-item menu, but still point somewhere.
    func testMenuLineIsShortButSpecific() {
        let line = SupportMessages.noHeadroomMenuLine
        XCTAssertLessThanOrEqual(line.count, 60,
                                 "Status-item menu lines get truncated beyond ~60 characters")
        XCTAssertTrue(line.contains("MacBook Pro"),
                      "Even the short form should say which Mac is needed")
    }

    /// "EDR" is Apple-internal jargon. Users know "HDR".
    func testUserFacingCopyLeadsWithHDR() {
        XCTAssertTrue(SupportMessages.noHeadroomMenuLine.contains("HDR"),
                      "Menu line should use the term users recognise")
        XCTAssertFalse(SupportMessages.noHeadroomMenuLine.contains("EDR"),
                       "Menu line should not expose the internal 'EDR' term")
    }
}
