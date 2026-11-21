import XCTest
@testable import MaxCandela

/// Pure-logic tests for the toolbox (everything in the menu that is not the
/// display). The tools' system calls are thin wrappers; what can go wrong
/// quietly is the arithmetic and the text handling, which is what is here.
final class ToolsTests: XCTestCase {

    // MARK: - Text tools

    func testCaseAndWhitespaceTools() {
        XCTAssertEqual(TextTransform.uppercase.apply(to: "max Candela"), "MAX CANDELA")
        XCTAssertEqual(TextTransform.lowercase.apply(to: "Max CANDELA"), "max candela")
        XCTAssertEqual(TextTransform.titleCase.apply(to: "max candela"), "Max Candela")
        // Trims each line and the whole, but keeps the line structure.
        XCTAssertEqual(TextTransform.trim.apply(to: "  a  \n\t b \n\n"), "a\nb")
    }

    func testLineTools() {
        // Natural order: 2 before 10, the way Finder sorts.
        XCTAssertEqual(TextTransform.sortLines.apply(to: "item 10\nitem 2\nitem 1"), "item 1\nitem 2\nitem 10")
        XCTAssertEqual(TextTransform.removeDuplicateLines.apply(to: "a\nb\na\nc\nb"), "a\nb\nc")
    }

    func testURLToolsRoundTrip() {
        let original = "a b&c=d/é?"
        let encoded = TextTransform.urlEncode.apply(to: original)
        XCTAssertEqual(encoded, "a%20b%26c%3Dd%2F%C3%A9%3F")
        XCTAssertEqual(TextTransform.urlDecode.apply(to: encoded ?? ""), original)
    }

    func testBase64RoundTripAndRejection() {
        XCTAssertEqual(TextTransform.base64Encode.apply(to: "héllo"), "aMOpbGxv")
        XCTAssertEqual(TextTransform.base64Decode.apply(to: " aMOpbGxv\n"), "héllo")
        // Not Base64: the clipboard must be left alone (nil), not blanked.
        XCTAssertNil(TextTransform.base64Decode.apply(to: "not base64!"))
    }

    func testJSONTools() {
        XCTAssertEqual(TextTransform.minifyJSON.apply(to: "{ \"b\": 1,\n \"a\": [1, 2] }"), "{\"a\":[1,2],\"b\":1}")
        let pretty = TextTransform.prettyJSON.apply(to: "{\"a\":\"http://x/y\"}")
        XCTAssertEqual(pretty?.contains("\n"), true)
        // Slashes must survive — escaped "\/" in a pasted URL is a classic.
        XCTAssertEqual(pretty?.contains("http://x/y"), true)
        XCTAssertNil(TextTransform.prettyJSON.apply(to: "{ nope"))
    }

    // MARK: - Clipboard history

    func testHistoryIsNewestFirstWithoutDuplicates() {
        var history = ClipboardHistory()
        history.add("one")
        history.add("two")
        history.add("one")
        XCTAssertEqual(history.entries, ["one", "two"])
        history.add("   \n")          // nothing worth remembering
        XCTAssertEqual(history.entries.count, 2)
    }

    func testHistoryIsCapped() {
        var history = ClipboardHistory()
        for index in 0..<(ClipboardHistory.freeCapacity + 5) { history.add("clip \(index)") }
        XCTAssertEqual(history.entries.count, ClipboardHistory.freeCapacity)
        XCTAssertEqual(history.entries.first, "clip \(ClipboardHistory.freeCapacity + 4)")
    }

    func testHistoryMenuTitleIsOneShortLine() {
        XCTAssertEqual(ClipboardHistory.menuTitle(for: "\n   first line  \nsecond"), "first line")
        let long = ClipboardHistory.menuTitle(for: String(repeating: "x", count: 200), limit: 20)
        XCTAssertEqual(long.count, 20)
        XCTAssertTrue(long.hasSuffix("…"))
    }

    // MARK: - Color picker

    func testHexRoundTrip() {
        XCTAssertEqual(ColorPickerTool.hex(red: 1, green: 0.5, blue: 0), "#FF8000")
        // Out-of-gamut samples (a wide-gamut display) clamp instead of wrapping.
        XCTAssertEqual(ColorPickerTool.hex(red: 1.2, green: -0.1, blue: 0), "#FF0000")
        let parts = ColorPickerTool.components(hex: "#FF8000")
        XCTAssertEqual(parts?.red, 1)
        XCTAssertEqual(parts?.green ?? 0, 128.0 / 255, accuracy: 0.0001)
        XCTAssertNil(ColorPickerTool.components(hex: "#XYZ"))
    }

    func testRecentColors() {
        XCTAssertEqual(ColorPickerTool.adding("#000000", to: ["#111111", "#000000"]), ["#000000", "#111111"])
        XCTAssertEqual(ColorPickerTool.adding("#9", to: ["#1", "#2", "#3"], limit: 3), ["#9", "#1", "#2"])
    }

    // MARK: - Timer + Keep Awake

    func testTimerFormat() {
        XCTAssertEqual(TimerTool.format(remaining: 1499), "24:59")
        XCTAssertEqual(TimerTool.format(remaining: 3900), "1:05:00")
        // Rounds up, so a fresh 5-minute timer reads 5:00, not 4:59.
        XCTAssertEqual(TimerTool.format(remaining: 299.4), "5:00")
        XCTAssertEqual(TimerTool.format(remaining: -3), "0:00")
    }

    func testKeepAwakeText() {
        XCTAssertEqual(KeepAwakeTool.durationTitle(minutes: 0), "Until I Turn It Off")
        XCTAssertEqual(KeepAwakeTool.durationTitle(minutes: 30), "For 30 Minutes")
        XCTAssertEqual(KeepAwakeTool.durationTitle(minutes: 60), "For 1 Hour")
        XCTAssertEqual(KeepAwakeTool.durationTitle(minutes: 240), "For 4 Hours")
        XCTAssertEqual(KeepAwakeTool.remainingText(seconds: 3900), "1 h 05 min left")
        XCTAssertEqual(KeepAwakeTool.remainingText(seconds: 20), "under a minute left")
    }

    // MARK: - System

    func testCPUUsageIsAShareOfElapsedTicks() {
        let before = SystemStats.CPUTicks(busy: 100, idle: 900)
        let after = SystemStats.CPUTicks(busy: 150, idle: 1050)
        XCTAssertEqual(SystemStats.cpuUsage(from: before, to: after) ?? -1, 0.25, accuracy: 0.0001)
        // No time passed, or counters went backwards: no figure, not 0% or NaN.
        XCTAssertNil(SystemStats.cpuUsage(from: before, to: before))
        XCTAssertNil(SystemStats.cpuUsage(from: after, to: before))
    }

    func testBatteryHealthRejectsNonsense() {
        XCTAssertEqual(SystemStats.health(rawMaxCapacity: 7357, designCapacity: 8694) ?? 0, 0.846, accuracy: 0.001)
        XCTAssertNil(SystemStats.health(rawMaxCapacity: nil, designCapacity: 8694))
        XCTAssertNil(SystemStats.health(rawMaxCapacity: 7357, designCapacity: 0))
        // A unit change in some future macOS must not show as "8400% health".
        XCTAssertNil(SystemStats.health(rawMaxCapacity: 84, designCapacity: 1))
    }

    func testUptimeText() {
        XCTAssertEqual(SystemStats.uptimeText(seconds: 8 * 60), "8 min")
        XCTAssertEqual(SystemStats.uptimeText(seconds: 5 * 3600 + 12 * 60), "5 h 12 min")
        XCTAssertEqual(SystemStats.uptimeText(seconds: 3 * 86_400 + 4 * 3600), "3 d 4 h")
    }

    func testPinnedFiguresForTheMenuBar() {
        let all = Set(SystemPin.allCases)
        XCTAssertEqual(SystemPin.statusText(pins: all, cpu: 0.124, memory: 0.61,
                                            diskFreeBytes: 212_400_000_000, battery: 84),
                       "CPU 12%  RAM 61%  SSD 212 GB  BAT 84%")
        // Only what was pinned, in the fixed order.
        XCTAssertEqual(SystemPin.statusText(pins: [.battery, .cpu], cpu: 0.5, memory: 0.9,
                                            diskFreeBytes: 1, battery: 100), "CPU 50%  BAT 100%")
        // Single digits are padded so the width holds as 9% becomes 10%.
        XCTAssertEqual(SystemPin.statusText(pins: [.cpu], cpu: 0.09, memory: nil, diskFreeBytes: nil, battery: nil),
                       "CPU \u{2007}9%")
        // No battery on a desktop: left out, not a dash. Nothing pinned: nil.
        XCTAssertEqual(SystemPin.statusText(pins: [.battery, .memory], cpu: nil, memory: 0.3,
                                            diskFreeBytes: nil, battery: nil), "RAM 30%")
        XCTAssertNil(SystemPin.statusText(pins: [], cpu: 0.5, memory: 0.5, diskFreeBytes: 5, battery: 5))
        XCTAssertNil(SystemPin.statusText(pins: [.cpu], cpu: nil, memory: nil, diskFreeBytes: nil, battery: nil))
    }

    func testCopyingARowTakesOnlyTheFigure() {
        XCTAssertEqual(SystemTool.value(ofRow: "Local IP — 192.168.1.20"), "192.168.1.20")
        XCTAssertEqual(SystemTool.value(ofRow: "CPU — 12%"), "12%")
    }

    func testLiveReadingsWorkOnThisMac() {
        // The one test that touches the system: these reads must not fail on
        // a real Mac, or the System menu would be a column of blanks.
        XCTAssertNotNil(SystemStats.cpuTicks())
        XCTAssertGreaterThan(SystemStats.memoryUsed() ?? 0, 0)
        XCTAssertGreaterThan(SystemStats.disk()?.total ?? 0, 0)
        XCTAssertNotNil(SystemStats.bootDate())
    }

    // MARK: - Menu sliders

    func testSliderValueText() {
        XCTAssertEqual(SliderMenuItemView.percent(0), "Off")
        XCTAssertEqual(SliderMenuItemView.percent(0.004), "Off")
        XCTAssertEqual(SliderMenuItemView.percent(0.4), "40%")
        XCTAssertEqual(SliderMenuItemView.percent(7), "100%")
    }

    // MARK: - Generate

    func testPasswordIsFullLengthFromTheAlphabetAndNotRepeated() {
        let first = Generator.password()
        XCTAssertEqual(first.count, 20)
        XCTAssertTrue(first.allSatisfy(Generator.passwordAlphabet.contains))
        // Look-alike characters are the reason the alphabet is hand-picked.
        XCTAssertFalse(Generator.passwordAlphabet.contains("0"))
        XCTAssertFalse(Generator.passwordAlphabet.contains("O"))
        XCTAssertFalse(Generator.passwordAlphabet.contains("l"))
        XCTAssertNotEqual(first, Generator.password())
        XCTAssertEqual(Generator.password(length: 64).count, 64)
    }

    func testTimestampsDescribeTheGivenMoment() {
        let moment = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(Generator.unixTime.make(now: moment), "1800000000")
        XCTAssertEqual(Generator.isoDate.make(now: moment), "2027-01-15T08:00:00Z")
        XCTAssertNotNil(UUID(uuidString: Generator.uuid.make()))
    }

    // MARK: - World clock

    func testWorldClockRowFlagsADifferentDay() throws {
        let newYork = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let tokyo = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        let locale = Locale(identifier: "en_US")
        // 2027-01-15 20:00 in New York is 10:00 the next morning in Tokyo.
        let evening = Date(timeIntervalSince1970: 1_800_000_000 + 17 * 3600)
        let there = WorldClockTool.row(city: "Tokyo", zone: tokyo, now: evening, local: newYork, locale: locale)
        XCTAssertTrue(there.hasPrefix("Tokyo — 10:00"), there)
        XCTAssertTrue(there.hasSuffix(", tomorrow"), there)
        let back = WorldClockTool.row(city: "New York", zone: newYork, now: evening, local: tokyo, locale: locale)
        XCTAssertTrue(back.hasSuffix(", yesterday"), back)
        // Same calendar day: no suffix.
        let same = WorldClockTool.row(city: "New York", zone: newYork, now: evening, local: newYork, locale: locale)
        XCTAssertFalse(same.contains(","), same)
    }

    func testEveryListedCityHasARealTimeZone() {
        for city in WorldClockTool.cities {
            XCTAssertNotNil(TimeZone(identifier: city.zone), city.name)
        }
    }

    // MARK: - Click behaviour + welcome

    func testExistingInstallsKeepTheClickTheyLearned() {
        XCTAssertTrue(MenuBarController.initialClickTogglesBoost(existingInstall: true))
        XCTAssertFalse(MenuBarController.initialClickTogglesBoost(existingInstall: false))
    }

    func testWelcomeDescribesTheClickTheAppActuallyHas() {
        XCTAssertTrue(WelcomeViewController.bodyText(clickTogglesBoost: true).contains("Double-click"))
        let toolbox = WelcomeViewController.bodyText(clickTogglesBoost: false)
        XCTAssertTrue(toolbox.contains("Click it for your tools"))
        XCTAssertFalse(toolbox.contains("Double-click"))
    }

    // MARK: - Clipboard manager (Pro)

    func testPinsSurviveEvictionAndSortFirst() {
        var history = ClipboardHistory()
        history.add("keep me", capacity: 3)
        history.togglePin("keep me")
        for index in 0..<10 { history.add("clip \(index)", capacity: 3) }
        // Three unpinned survive, plus the pin — pinning means it stays.
        XCTAssertEqual(history.entries.count, 4)
        XCTAssertEqual(history.ordered().first, "keep me")
        XCTAssertEqual(history.ordered().dropFirst().first, "clip 9")
        history.remove("keep me")
        XCTAssertFalse(history.isPinned("keep me"))
    }

    func testSearchIgnoresCaseAndAccents() {
        var history = ClipboardHistory()
        ["Café menu", "invoice 42", "CAFETERIA"].forEach { history.add($0) }
        XCTAssertEqual(history.ordered(matching: "cafe"), ["CAFETERIA", "Café menu"])
        XCTAssertEqual(history.ordered(matching: "  "), history.entries)
        XCTAssertTrue(history.ordered(matching: "zzz").isEmpty)
    }

    func testDroppingToTheFreeTierTrimsButKeepsPins() {
        var history = ClipboardHistory()
        for index in 0..<40 { history.add("clip \(index)", capacity: ClipboardHistory.proCapacity) }
        history.togglePin("clip 0")
        history.trim(to: ClipboardHistory.freeCapacity)
        XCTAssertEqual(history.entries.count, ClipboardHistory.freeCapacity + 1)
        XCTAssertTrue(history.entries.contains("clip 0"))
    }

    func testHistoryRoundTripsThroughItsSavedForm() throws {
        var history = ClipboardHistory()
        history.add("a")
        history.add("b")
        history.togglePin("a")
        let restored = try JSONDecoder().decode(ClipboardHistory.self, from: JSONEncoder().encode(history))
        XCTAssertEqual(restored, history)
    }

    func testHashesAndJWT() {
        XCTAssertEqual(TextTransform.sha256.apply(to: "abc"),
                       "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        XCTAssertEqual(TextTransform.md5.apply(to: "abc"), "900150983cd24fb0d6963f7d28e17f72")
        // {"alg":"HS256","typ":"JWT"} . {"sub":"1234567890","name":"John Doe","iat":1516239022}
        let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
        let decoded = TextTransform.decodeJWT.apply(to: token)
        XCTAssertEqual(decoded?.contains("\"alg\" : \"HS256\""), true)
        XCTAssertEqual(decoded?.contains("\"name\" : \"John Doe\""), true)
        XCTAssertNil(TextTransform.decodeJWT.apply(to: "not.a.jwt"))
        XCTAssertNil(TextTransform.decodeJWT.apply(to: "only-one-part"))
    }

    // MARK: - Pro gate

    func testProGateRunsOrAsksAndNotifiesOnlyOnChange() {
        let gate = ProGate()
        var asked = 0, ran = 0, changes: [Bool] = []
        gate.requestUpgrade = { asked += 1 }
        gate.observe { changes.append($0) }
        gate.run { ran += 1 }
        XCTAssertEqual([asked, ran], [1, 0])      // closed until the licence resolves
        gate.set(allowed: true)
        gate.set(allowed: true)                   // no second notification
        gate.run { ran += 1 }
        XCTAssertEqual([asked, ran], [1, 1])
        gate.set(allowed: false)
        XCTAssertEqual(changes, [true, false])
    }

    // MARK: - Window snapping

    func testSnapRegionsTileTheUsableArea() {
        // A screen whose usable area starts above a 70 pt Dock.
        let visible = CGRect(x: 0, y: 70, width: 1600, height: 900)
        XCTAssertEqual(SnapRegion.leftHalf.frame(in: visible), CGRect(x: 0, y: 70, width: 800, height: 900))
        XCTAssertEqual(SnapRegion.rightHalf.frame(in: visible), CGRect(x: 800, y: 70, width: 800, height: 900))
        // AppKit's y goes up, so the TOP half is the one with the larger y.
        XCTAssertEqual(SnapRegion.topHalf.frame(in: visible), CGRect(x: 0, y: 520, width: 1600, height: 450))
        XCTAssertEqual(SnapRegion.bottomRight.frame(in: visible), CGRect(x: 800, y: 70, width: 800, height: 450))
        XCTAssertEqual(SnapRegion.maximize.frame(in: visible), visible)
        // The four quarters cover the area exactly, with no overlap.
        let quarters: [SnapRegion] = [.topLeft, .topRight, .bottomLeft, .bottomRight]
        XCTAssertEqual(quarters.map { $0.frame(in: visible) }.reduce(CGRect.null) { $0.union($1) }, visible)
    }

    func testCenterKeepsSizeAndNeverExceedsTheScreen() {
        let visible = CGRect(x: 0, y: 70, width: 1600, height: 900)
        XCTAssertEqual(SnapRegion.center.frame(in: visible, current: CGSize(width: 600, height: 400)),
                       CGRect(x: 500, y: 320, width: 600, height: 400))
        XCTAssertEqual(SnapRegion.center.frame(in: visible, current: CGSize(width: 5000, height: 5000)), visible)
    }

    func testAccessibilityOriginFlipsY() {
        // Primary screen 1000 pt tall; a window whose top edge is 30 pt below
        // the top of the screen has AX y == 30.
        let frame = CGRect(x: 100, y: 370, width: 800, height: 600)
        XCTAssertEqual(SnapRegion.accessibilityOrigin(of: frame, primaryScreenHeight: 1000), CGPoint(x: 100, y: 30))
        // A screen arranged to the left has negative x, which must pass through.
        XCTAssertEqual(SnapRegion.accessibilityOrigin(of: frame.offsetBy(dx: -2000, dy: 0), primaryScreenHeight: 1000).x, -1900)
    }

    // MARK: - Copy text from screen

    func testCaptureRectIsRelativeToItsDisplayWithYDown() {
        // A second display sitting to the right of, and higher than, the main one.
        let screen = CGRect(x: 1728, y: 200, width: 1920, height: 1080)
        let selection = CGRect(x: 1828, y: 1080, width: 300, height: 100)   // 100 pt below its top edge
        XCTAssertEqual(ScreenTextTool.captureRect(selection: selection, screenFrame: screen),
                       CGRect(x: 100, y: 100, width: 300, height: 100))
    }

    func testRecognisedLinesAreJoinedWithoutBlanks() {
        XCTAssertEqual(ScreenTextTool.join(lines: ["  Total  ", "", " $42.00"]), "Total\n$42.00")
        XCTAssertEqual(ScreenTextTool.join(lines: []), "")
    }

    // MARK: - Shortcuts

    func testShortcutURLEncodesTheName() {
        XCTAssertEqual(ShortcutsTool.runURL(name: " Dark Mode & Focus ")?.absoluteString,
                       "shortcuts://run-shortcut?name=Dark%20Mode%20%26%20Focus")
        XCTAssertNil(ShortcutsTool.runURL(name: "   "))
    }

    func testShortcutNamesAreTrimmedAndNotRepeated() {
        XCTAssertEqual(ShortcutsTool.adding(" Dark Mode ", to: []), ["Dark Mode"])
        XCTAssertEqual(ShortcutsTool.adding("dark mode", to: ["Dark Mode"]), ["Dark Mode"])
        XCTAssertEqual(ShortcutsTool.adding("", to: ["Dark Mode"]), ["Dark Mode"])
    }

    // MARK: - Next meeting

    func testJoinLinkIsFoundInEventText() {
        let notes = "Agenda attached.\nJoin: https://us02web.zoom.us/j/123456789?pwd=abc. See you there"
        XCTAssertEqual(CalendarTool.joinURL(in: notes)?.host, "us02web.zoom.us")
        XCTAssertEqual(CalendarTool.joinURL(in: "https://meet.google.com/abc-defg-hij")?.path, "/abc-defg-hij")
        // An ordinary link is not a call.
        XCTAssertNil(CalendarTool.joinURL(in: "Slides: https://example.com/deck"))
    }

    func testMeetingCountdownText() {
        XCTAssertEqual(CalendarTool.relativeText(minutes: 0), "now")
        XCTAssertEqual(CalendarTool.relativeText(minutes: -5), "now")
        XCTAssertEqual(CalendarTool.relativeText(minutes: 12), "in 12 min")
        XCTAssertEqual(CalendarTool.relativeText(minutes: 125), "in 2 h 05 min")
    }

    // MARK: - Hide menu bar icons + sound

    func testHiderLengths() {
        XCTAssertEqual(MenuBarHiderTool.length(collapsed: false), MenuBarHiderTool.dividerLength)
        XCTAssertGreaterThan(MenuBarHiderTool.length(collapsed: true), 6000)   // wider than any display
    }

    func testThisMacReportsAudioDevices() {
        // Reads only — proves the HAL enumeration works here, nothing more.
        let devices = AudioDevices.all()
        XCTAssertFalse(devices.isEmpty)
        XCTAssertTrue(devices.contains { $0.hasOutput })
        XCTAssertNotNil(AudioDevices.defaultDevice(input: false))
    }
}
