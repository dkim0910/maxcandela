import XCTest
@testable import MaxCandela

final class MenuGroupsTests: XCTestCase {
    /// Every tool in `MenuBarController.tools` must have a group, or the
    /// grouped menu shows it loose at the top level. Read from the source so
    /// a newly added tool fails this test until someone places it.
    func testEveryRegisteredToolHasAGroup() throws {
        let source = try String(contentsOf: URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/MaxCandela/MenuBarController.swift"), encoding: .utf8)
        let start = try XCTUnwrap(source.range(of: "private let tools: [MenuTool] = ["))
        let end = try XCTUnwrap(source.range(of: "]", options: [], range: start.upperBound..<source.endIndex))
        let list = String(source[start.upperBound..<end.lowerBound])
        let names = list.matches(of: #/([A-Z][A-Za-z]+Tool)\(/#).map { String($0.1) }
        XCTAssertGreaterThan(names.count, 20)
        for name in names {
            XCTAssertNotNil(MenuGroup.group(forToolNamed: name), "\(name) has no MenuGroup")
        }
    }

    func testUnknownToolsStayAtTheTopLevel() {
        XCTAssertNil(MenuGroup.group(forToolNamed: "SomeFutureTool"))
    }

    func testLayoutDefaultsToFlatAndHonoursTheChoice() {
        XCTAssertEqual(MenuLayout.resolve(stored: nil, override: nil), .flat)
        XCTAssertEqual(MenuLayout.resolve(stored: "flat", override: nil), .flat)
        XCTAssertEqual(MenuLayout.resolve(stored: "grouped", override: nil), .grouped)
        XCTAssertEqual(MenuLayout.resolve(stored: "nonsense", override: nil), .flat)
        XCTAssertEqual(MenuLayout.resolve(stored: "grouped", override: "flat"), .flat)
    }

    func testPaywallListsOnlyTheProToolsPresent() {
        XCTAssertEqual(MenuBarController.proToolList(["Screenshot", "Copy Text from Screen…"]),
                       "Screenshot, Copy Text from Screen and the searchable clipboard history")
        XCTAssertEqual(MenuBarController.proToolList([]), "the searchable clipboard history")
        XCTAssertFalse(MenuBarController.proToolList(["Screenshot"]).contains("Window Snapping"))
    }
}
