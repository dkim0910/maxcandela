import XCTest
@testable import MaxCandela

/// The Calendar tool's pure logic: month layout for any first weekday and
/// month length, ISO week numbers across year boundaries, and which grid day
/// an event lands on across time zones and DST. Every calendar here is built
/// explicitly (zone, locale, first weekday) so the results do not depend on
/// the Mac running the tests.
final class MonthCalendarTests: XCTestCase {

    private func calendar(_ zone: String = "UTC", firstWeekday: Int = 1, locale: String = "en_US") throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: zone))
        calendar.locale = Locale(identifier: locale)
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0,
                      in calendar: Calendar) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)))
    }

    // MARK: - Layout

    func testLeadingDaysForEveryFirstWeekday() throws {
        // Pure: every combination puts the 1st under its own weekday column.
        for weekdayOfFirst in 1 ... 7 {
            for firstWeekday in 1 ... 7 {
                let leading = MonthLayout.leadingDays(weekdayOfFirst: weekdayOfFirst, firstWeekday: firstWeekday)
                XCTAssertTrue((0 ... 6).contains(leading))
                XCTAssertEqual((firstWeekday - 1 + leading) % 7 + 1, weekdayOfFirst)
            }
        }
        // November 2026 starts on a Sunday.
        let expected = [1: 0, 2: 6, 3: 5, 4: 4, 5: 3, 6: 2, 7: 1]
        for (firstWeekday, leading) in expected {
            let cal = try calendar(firstWeekday: firstWeekday)
            let layout = MonthLayout(containing: try date(2026, 11, 22, in: cal), calendar: cal)
            XCTAssertEqual(layout.leadingDays, leading, "first weekday \(firstWeekday)")
            XCTAssertEqual(layout.cells[leading].day, 1)
            XCTAssertTrue(layout.cells[leading].isInMonth)
            XCTAssertEqual(cal.component(.weekday, from: layout.cells[0].start), firstWeekday)
            if leading > 0 {
                XCTAssertEqual(layout.cells[leading - 1].day, 31)   // October 31
                XCTAssertFalse(layout.cells[leading - 1].isInMonth)
            }
        }
    }

    func testMonthLengthsIncludingLeapYears() throws {
        let cal = try calendar()
        let cases: [(year: Int, month: Int, days: Int)] = [
            (2024, 2, 29), (2025, 2, 28), (2000, 2, 29), (2100, 2, 28),   // leap rules: 4, 100, 400
            (2026, 4, 30), (2026, 1, 31), (2026, 12, 31),
        ]
        for c in cases {
            let layout = MonthLayout(containing: try date(c.year, c.month, 10, in: cal), calendar: cal)
            XCTAssertEqual(layout.daysInMonth, c.days, "\(c.year)-\(c.month)")
            let inMonth = layout.cells.filter(\.isInMonth)
            XCTAssertEqual(inMonth.map(\.day), Array(1 ... c.days), "\(c.year)-\(c.month)")
            XCTAssertEqual(layout.cells.count, 42)
        }
    }

    func testGridIsAlwaysSixRowsFilledFromTheNeighbouringMonths() throws {
        let cal = try calendar()
        // February 2026: 28 days starting on a Sunday — fills exactly four
        // rows, and the remaining two are March, dimmed.
        let february = MonthLayout(containing: try date(2026, 2, 1, in: cal), calendar: cal)
        XCTAssertEqual(february.leadingDays, 0)
        XCTAssertEqual(february.cells[27].day, 28)
        XCTAssertEqual(february.cells[28...].map(\.day), Array(1 ... 14))
        XCTAssertTrue(february.cells[28...].allSatisfy { !$0.isInMonth })

        // August 2026: 31 days starting on a Saturday — needs all six rows.
        let august = MonthLayout(containing: try date(2026, 8, 15, in: cal), calendar: cal)
        XCTAssertEqual(august.leadingDays, 6)
        XCTAssertEqual(august.cells[..<6].map(\.day), Array(26 ... 31))     // July
        XCTAssertEqual(august.cells[36].day, 31)
        XCTAssertTrue(august.cells[36].isInMonth)
        XCTAssertEqual(august.cells[37...].map(\.day), Array(1 ... 5))      // September
    }

    func testDaysAreCalendarDaysAcrossDST() throws {
        let cal = try calendar("America/New_York")
        for (month, shortDay, hours) in [(3, 8, 23.0), (11, 1, 25.0)] {
            let layout = MonthLayout(containing: try date(2026, month, 15, in: cal), calendar: cal)
            for cell in layout.cells {
                let parts = cal.dateComponents([.hour, .minute], from: cell.start)
                XCTAssertEqual([parts.hour, parts.minute], [0, 0])
            }
            for index in 0 ..< layout.cells.count - 1 {
                let next = cal.date(byAdding: .day, value: 1, to: layout.cells[index].start)
                XCTAssertEqual(cal.dateComponents([.year, .month, .day], from: try XCTUnwrap(next)),
                               cal.dateComponents([.year, .month, .day], from: layout.cells[index + 1].start))
            }
            // The DST day really is 23 or 25 hours long in the layout.
            let index = try XCTUnwrap(layout.index(containing: try date(2026, month, shortDay, in: cal)))
            let length = layout.boundaries[index + 1].timeIntervalSince(layout.boundaries[index])
            XCTAssertEqual(length, hours * 3600)
        }
    }

    func testADayWithNoMidnightIsStillOneCell() throws {
        // Santiago's clocks go from 00:00 straight to 01:00 on 6 September
        // 2026, so that day starts at 01:00.
        let cal = try calendar("America/Santiago")
        let layout = MonthLayout(containing: try date(2026, 9, 10, in: cal), calendar: cal)
        XCTAssertEqual(layout.cells.filter(\.isInMonth).map(\.day), Array(1 ... 30))
        let sixth = layout.cells[layout.leadingDays + 5]
        XCTAssertEqual(sixth.day, 6)
        XCTAssertEqual(cal.component(.hour, from: sixth.start), 1)
    }

    func testIndexContainingDate() throws {
        let cal = try calendar()
        let layout = MonthLayout(containing: try date(2026, 11, 22, in: cal), calendar: cal)
        XCTAssertEqual(layout.index(containing: layout.boundaries[0]), 0)
        XCTAssertEqual(layout.index(containing: try date(2026, 11, 22, 23, 59, in: cal)), 21)
        XCTAssertNil(layout.index(containing: layout.boundaries[0].addingTimeInterval(-1)))
        XCTAssertNil(layout.index(containing: layout.boundaries[42]))
        XCTAssertEqual(layout.interval.start, layout.boundaries[0])
        XCTAssertEqual(layout.interval.end, layout.boundaries[42])
    }

    // MARK: - Week numbers

    func testISOWeekNumbersAcrossYearBoundaries() throws {
        // Monday rows, January 2027: the first row starts Monday 28 December
        // 2026, which is in week 53 — 2026 has 53 ISO weeks.
        let monday = try calendar(firstWeekday: 2)
        XCTAssertEqual(MonthLayout(containing: try date(2027, 1, 15, in: monday), calendar: monday).weekNumbers,
                       [53, 1, 2, 3, 4, 5])
        // December 2024: Monday 30 December 2024 is already week 1 of 2025.
        XCTAssertEqual(MonthLayout(containing: try date(2024, 12, 15, in: monday), calendar: monday).weekNumbers,
                       [48, 49, 50, 51, 52, 1])

        // Sunday rows straddle two ISO weeks; the row is numbered by the week
        // holding most of it. January 2021 starts on a Friday.
        let sunday = try calendar(firstWeekday: 1)
        XCTAssertEqual(MonthLayout(containing: try date(2021, 1, 15, in: sunday), calendar: sunday).weekNumbers,
                       [53, 1, 2, 3, 4, 5])
        // Saturday rows: Sat 2 – Fri 8 January 2021 has two days of week 53
        // and five of week 1, so it is week 1.
        let saturday = try calendar(firstWeekday: 7)
        XCTAssertEqual(MonthLayout(containing: try date(2021, 1, 15, in: saturday), calendar: saturday).weekNumbers,
                       [53, 1, 2, 3, 4, 5])
    }

    func testISOWeekOfSingleDays() throws {
        let utc = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let cal = try calendar()
        XCTAssertEqual(MonthLayout.isoWeek(ofRowWithMiddleDay: try date(2026, 12, 31, in: cal), timeZone: utc), 53)
        XCTAssertEqual(MonthLayout.isoWeek(ofRowWithMiddleDay: try date(2027, 1, 1, in: cal), timeZone: utc), 53)
        XCTAssertEqual(MonthLayout.isoWeek(ofRowWithMiddleDay: try date(2027, 1, 4, in: cal), timeZone: utc), 1)
        XCTAssertEqual(MonthLayout.isoWeek(ofRowWithMiddleDay: try date(2024, 12, 30, in: cal), timeZone: utc), 1)
        // Late on Sunday 3 January 2021 in Los Angeles is Monday (week 1) in
        // UTC: the week is read in the user's zone.
        let la = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let lateSunday = try date(2021, 1, 4, 6, in: cal)   // 22:00 on the 3rd in LA
        XCTAssertEqual(MonthLayout.isoWeek(ofRowWithMiddleDay: lateSunday, timeZone: la), 53)
        XCTAssertEqual(MonthLayout.isoWeek(ofRowWithMiddleDay: lateSunday, timeZone: utc), 1)
    }

    // MARK: - Names

    func testWeekdaySymbolsStartOnTheFirstWeekday() throws {
        let week = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        XCTAssertEqual(MonthLayout.ordered(week, firstWeekday: 1), week)
        XCTAssertEqual(MonthLayout.ordered(week, firstWeekday: 2), ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
        XCTAssertEqual(MonthLayout.ordered(week, firstWeekday: 7), ["Sat", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri"])
        XCTAssertEqual(MonthLayout.ordered(week, firstWeekday: 9), week)   // nonsense in, unchanged out

        let symbols = MonthLayout.weekdaySymbols(calendar: try calendar(firstWeekday: 2))
        XCTAssertEqual(symbols.short.first, "Mon")
        XCTAssertEqual(symbols.narrow, ["M", "T", "W", "T", "F", "S", "S"])

        // A German calendar starts on Monday by itself, from its locale.
        var german = Calendar(identifier: .gregorian)
        german.locale = Locale(identifier: "de_DE")
        XCTAssertEqual(german.firstWeekday, 2)
        let layout = MonthLayout(containing: try date(2026, 11, 22, in: german), calendar: german)
        XCTAssertEqual(german.component(.weekday, from: layout.cells[0].start), 2)
    }

    func testTitlesAndDayNumbersFollowTheLocale() throws {
        let november = try date(2026, 11, 22, in: try calendar())
        XCTAssertEqual(MonthLayout.title(for: november, calendar: try calendar()), "November 2026")
        XCTAssertEqual(MonthLayout.title(for: november, calendar: try calendar(locale: "fr_FR")), "novembre 2026")

        let cal = try calendar()
        let layout = MonthLayout(containing: november, calendar: cal)
        XCTAssertEqual(layout.dayLabels(calendar: cal)[21], "22")
        let arabic = try calendar(locale: "ar_EG")
        XCTAssertEqual(MonthLayout(containing: november, calendar: arabic).dayLabels(calendar: arabic)[21], "٢٢")
    }

    func testStatusTextAndDayHeadings() throws {
        let cal = try calendar()
        let today = try date(2026, 11, 22, in: cal)
        XCTAssertEqual(MonthCalendarTool.statusText(for: today, calendar: cal), "Sun, Nov 22")
        XCTAssertEqual(MonthCalendarTool.dayHeading(for: cal.startOfDay(for: today), today: today, calendar: cal), "Today")
        XCTAssertEqual(MonthCalendarTool.dayHeading(for: try date(2026, 11, 23, 0, in: cal), today: today, calendar: cal),
                       "Monday, November 23")
        XCTAssertEqual(MonthCalendarTool.dayHeading(for: try date(2027, 1, 1, 0, in: cal), today: today, calendar: cal),
                       "Friday, January 1, 2027")
    }

    func testEventTimeText() throws {
        let cal = try calendar()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = cal.timeZone
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let dayStart = try date(2026, 11, 22, 0, in: cal), dayEnd = try date(2026, 11, 23, 0, in: cal)
        let nineThirty = try date(2026, 11, 22, 9, 30, in: cal)
        let morning = EventSpan(start: nineThirty, end: try date(2026, 11, 22, 10, 0, in: cal))
        XCTAssertEqual(MonthCalendarTool.timeText(morning, isAllDay: false, dayStart: dayStart, dayEnd: dayEnd, formatter: formatter),
                       formatter.string(from: nineThirty))
        XCTAssertEqual(MonthCalendarTool.timeText(morning, isAllDay: true, dayStart: dayStart, dayEnd: dayEnd, formatter: formatter),
                       "All day")
        let overnight = EventSpan(start: try date(2026, 11, 21, 22, in: cal), end: nineThirty)
        XCTAssertEqual(MonthCalendarTool.timeText(overnight, isAllDay: false, dayStart: dayStart, dayEnd: dayEnd, formatter: formatter),
                       "until \(formatter.string(from: nineThirty))")
        let conference = EventSpan(start: try date(2026, 11, 21, 9, in: cal), end: try date(2026, 11, 24, 17, in: cal))
        XCTAssertEqual(MonthCalendarTool.timeText(conference, isAllDay: false, dayStart: dayStart, dayEnd: dayEnd, formatter: formatter),
                       "All day")
    }

    // MARK: - Event days

    func testTheSameMomentLandsOnTheLocalDay() throws {
        // 07:30 UTC on 23 November 2026 is the evening of the 22nd in Los
        // Angeles and the afternoon of the 23rd in Tokyo. November 2026
        // starts on a Sunday, so with Sunday rows day N is cell N - 1.
        let moment = try date(2026, 11, 23, 7, 30, in: try calendar())
        let span = EventSpan(start: moment, end: moment.addingTimeInterval(1800))
        let la = try calendar("America/Los_Angeles")
        let tokyo = try calendar("Asia/Tokyo")
        XCTAssertEqual(MonthLayout(containing: moment, calendar: la).eventDays([span]), [21])
        XCTAssertEqual(MonthLayout(containing: moment, calendar: tokyo).eventDays([span]), [22])
    }

    func testBucketingFollowsShortAndLongDSTDays() throws {
        let cal = try calendar("America/New_York")
        // March 2026 starts on a Sunday: day N is cell N - 1.
        let march = MonthLayout(containing: try date(2026, 3, 15, in: cal), calendar: cal)
        // 00:30 on the 9th, just after the 23-hour day. Stepping 24 hours from
        // midnight on the 8th would wrongly call this the 8th.
        let justAfter = try date(2026, 3, 9, 0, 30, in: cal)
        XCTAssertEqual(march.eventDays([EventSpan(start: justAfter, end: justAfter.addingTimeInterval(900))]), [8])
        let lateOnTheEighth = try date(2026, 3, 8, 23, 30, in: cal)
        XCTAssertEqual(march.eventDays([EventSpan(start: lateOnTheEighth, end: lateOnTheEighth.addingTimeInterval(900))]), [7])

        // November 2026: the 1st has 25 hours; 23:30 is still the 1st.
        let november = MonthLayout(containing: try date(2026, 11, 15, in: cal), calendar: cal)
        let lateOnTheFirst = try date(2026, 11, 1, 23, 30, in: cal)
        XCTAssertEqual(november.eventDays([EventSpan(start: lateOnTheFirst, end: lateOnTheFirst.addingTimeInterval(900))]), [0])
        let earlyOnTheSecond = try date(2026, 11, 2, 0, 15, in: cal)
        XCTAssertEqual(november.eventDays([EventSpan(start: earlyOnTheSecond, end: earlyOnTheSecond.addingTimeInterval(900))]), [1])
    }

    func testEventEdges() throws {
        let cal = try calendar("America/New_York")
        let march = MonthLayout(containing: try date(2026, 3, 15, in: cal), calendar: cal)
        // Across the DST night: the 7th, 8th and 9th.
        let trip = EventSpan(start: try date(2026, 3, 7, 22, in: cal), end: try date(2026, 3, 9, 1, in: cal))
        XCTAssertEqual(march.eventDays([trip]), [6, 7, 8])
        // Ending exactly at midnight does not touch the next day.
        let evening = EventSpan(start: try date(2026, 3, 8, 20, in: cal), end: try date(2026, 3, 9, 0, in: cal))
        XCTAssertEqual(march.eventDays([evening]), [7])
        // A zero-length event at midnight belongs to the day it starts.
        let midnight = try date(2026, 3, 9, 0, in: cal)
        XCTAssertEqual(march.eventDays([EventSpan(start: midnight, end: midnight)]), [8])
        // An all-day event the way EventKit reports one: local midnight to
        // 23:59:59 the same day.
        let allDay = EventSpan(start: try date(2026, 3, 8, 0, in: cal), end: try date(2026, 3, 8, 23, 59, in: cal).addingTimeInterval(59))
        XCTAssertEqual(march.eventDays([allDay]), [7])
        // Outside the grid: nothing. Covering all of it: every cell.
        let january = EventSpan(start: try date(2026, 1, 10, in: cal), end: try date(2026, 1, 11, in: cal))
        XCTAssertEqual(march.eventDays([january]), [])
        let everything = EventSpan(start: try date(2025, 12, 1, in: cal), end: try date(2026, 6, 1, in: cal))
        XCTAssertEqual(march.eventDays([everything]), Set(0 ..< 42))
        XCTAssertTrue(march.span(trip, fallsOn: 7))
        XCTAssertFalse(march.span(trip, fallsOn: 9))
    }

    // MARK: - Hit testing

    func testEveryCellIsHitAtItsCentreAndNothingOutsideTheGrid() {
        for weeks in [false, true] {
            let natural = MonthGridGeometry.naturalWidth(showsWeekNumbers: weeks)
            for width in [natural, natural + 100] {
                let g = MonthGridGeometry(width: width, showsWeekNumbers: weeks)
                for index in 0 ..< MonthLayout.cellCount {
                    let rect = g.cellRect(index)
                    XCTAssertEqual(g.cellIndex(at: CGPoint(x: rect.midX, y: rect.midY)), index)
                    XCTAssertEqual(g.cellIndex(at: CGPoint(x: rect.minX + 0.5, y: rect.maxY - 0.5)), index)
                }
                let first = g.cellRect(0), last = g.cellRect(MonthLayout.cellCount - 1)
                XCTAssertNil(g.cellIndex(at: CGPoint(x: first.midX, y: first.minY - 1)))   // weekday row
                XCTAssertNil(g.cellIndex(at: CGPoint(x: first.minX - 1, y: first.midY)))   // week column / margin
                XCTAssertNil(g.cellIndex(at: CGPoint(x: last.maxX + 1, y: last.midY)))
                XCTAssertNil(g.cellIndex(at: CGPoint(x: last.midX, y: last.maxY + 1)))
                XCTAssertLessThanOrEqual(last.maxY, MonthGridGeometry.height)
            }
        }
    }

    func testGridIsCentredWhenTheMenuIsWider() {
        let natural = MonthGridGeometry.naturalWidth(showsWeekNumbers: false)
        XCTAssertEqual(MonthGridGeometry(width: natural, showsWeekNumbers: false).blockX, MonthGridGeometry.inset)
        XCTAssertEqual(MonthGridGeometry(width: natural + 100, showsWeekNumbers: false).blockX, MonthGridGeometry.inset + 50)
        // The week column sits left of the days, not over them.
        let g = MonthGridGeometry(width: 400, showsWeekNumbers: true)
        XCTAssertEqual(g.weekNumberRect(row: 0).maxX, g.cellRect(0).minX)
    }
}
