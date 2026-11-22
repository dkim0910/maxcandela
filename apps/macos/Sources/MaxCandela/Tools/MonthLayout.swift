import Foundation

/// The arithmetic behind the Calendar tool's month grid, kept free of AppKit
/// so all of it is unit-tested: where the 1st falls for any first weekday,
/// 28- to 31-day months, ISO week numbers across a year boundary, and which
/// grid day an event lands on across time zones and DST.
///
/// Every day boundary comes from `Calendar` arithmetic, never from adding
/// 86,400 seconds: a DST day is 23 or 25 hours long, and in a few zones
/// (Santiago in September) a day starts at 01:00 because midnight is skipped.
/// The calendar passed in decides everything else — its time zone, its first
/// weekday, and its kind (Gregorian or not).
struct MonthLayout: Equatable {
    /// Always six rows. A month needs four to six; a grid whose height changed
    /// while paging through months would resize the open menu under the
    /// pointer.
    static let rows = 6
    static let cellCount = rows * 7

    struct Cell: Equatable {
        /// The first instant of the day (normally midnight).
        let start: Date
        /// Day of the month, in the layout's calendar.
        let day: Int
        /// False for the previous and next month's days that fill the grid.
        let isInMonth: Bool
    }

    let monthStart: Date
    /// How many of the previous month's days come before the 1st.
    let leadingDays: Int
    let daysInMonth: Int
    let cells: [Cell]
    /// ISO 8601 week number of each row (see `isoWeek(ofRowWithMiddleDay:timeZone:)`).
    let weekNumbers: [Int]
    /// `cells.count + 1` day starts; cell i is `boundaries[i] ..< boundaries[i + 1]`.
    let boundaries: [Date]

    init(containing date: Date, calendar: Calendar) {
        let monthStart = calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        let leading = Self.leadingDays(weekdayOfFirst: calendar.component(.weekday, from: monthStart),
                                       firstWeekday: calendar.firstWeekday)

        // Step from noon, which every day has, and take each day's start —
        // stepping from midnight would land on a skipped hour now and then.
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: monthStart) ?? monthStart
        let boundaries = (-leading ... Self.cellCount - leading).map { offset -> Date in
            calendar.startOfDay(for: calendar.date(byAdding: .day, value: offset, to: noon) ?? noon)
        }

        self.monthStart = monthStart
        self.leadingDays = leading
        self.daysInMonth = daysInMonth
        self.boundaries = boundaries
        self.cells = (0 ..< Self.cellCount).map { index in
            Cell(start: boundaries[index],
                 day: calendar.component(.day, from: boundaries[index]),
                 isInMonth: index >= leading && index < leading + daysInMonth)
        }
        self.weekNumbers = (0 ..< Self.rows).map { row in
            Self.isoWeek(ofRowWithMiddleDay: boundaries[row * 7 + 3], timeZone: calendar.timeZone)
        }
    }

    /// Pure, unit-tested. `weekday` values are Calendar's: 1 = Sunday … 7 = Saturday.
    static func leadingDays(weekdayOfFirst: Int, firstWeekday: Int) -> Int {
        ((weekdayOfFirst - firstWeekday) % 7 + 7) % 7
    }

    /// The ISO week shown for a row, given the row's *middle* (fourth) day.
    /// ISO weeks run Monday–Sunday; a row that starts on another weekday
    /// straddles two of them, and the middle day always belongs to the one
    /// holding at least four of the row's seven days — the same majority rule
    /// ISO itself uses to number the first week of a year.
    static func isoWeek(ofRowWithMiddleDay middleDay: Date, timeZone: TimeZone) -> Int {
        var iso = Calendar(identifier: .gregorian)
        iso.firstWeekday = 2            // Monday
        iso.minimumDaysInFirstWeek = 4  // the week with the year's first Thursday is week 1
        iso.timeZone = timeZone
        return iso.component(.weekOfYear, from: middleDay)
    }

    /// Pure, unit-tested. Calendar's weekday symbols start on Sunday; the grid
    /// starts on the user's first weekday.
    static func ordered<T>(_ symbols: [T], firstWeekday: Int) -> [T] {
        guard symbols.count == 7, (1 ... 7).contains(firstWeekday) else { return symbols }
        let shift = firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    /// The cell holding `date`, or nil when it is outside the grid.
    func index(containing date: Date) -> Int? {
        guard let first = boundaries.first, let last = boundaries.last,
              date >= first, date < last else { return nil }
        return (0 ..< cells.count).first { date < boundaries[$0 + 1] }
    }

    /// The span the whole grid covers — what to ask EventKit for.
    var interval: DateInterval {
        DateInterval(start: boundaries[0], end: boundaries[boundaries.count - 1])
    }

    /// Pure, unit-tested. Cells on which at least one span falls.
    func eventDays(_ spans: [EventSpan]) -> Set<Int> {
        var days = Set<Int>()
        for span in spans {
            for index in 0 ..< cells.count where span.overlaps(start: boundaries[index], end: boundaries[index + 1]) {
                days.insert(index)
            }
        }
        return days
    }

    /// Whether `span` falls on cell `index`.
    func span(_ span: EventSpan, fallsOn index: Int) -> Bool {
        span.overlaps(start: boundaries[index], end: boundaries[index + 1])
    }
}

/// An event's time span, stripped of EventKit so the bucketing is testable.
struct EventSpan: Equatable {
    let start: Date
    let end: Date

    /// Half-open: an event that ends at midnight does not mark the next day.
    /// A zero-length event belongs to the day it starts on.
    func overlaps(start dayStart: Date, end dayEnd: Date) -> Bool {
        if end <= start { return start >= dayStart && start < dayEnd }
        return start < dayEnd && end > dayStart
    }
}

// MARK: - Text

extension MonthLayout {
    /// "November 2026", in the calendar's locale (and its own month names —
    /// a Hebrew or Buddhist calendar names its months its own way).
    static func title(for monthStart: Date, calendar: Calendar) -> String {
        formatter(template: "LLLLy", calendar: calendar).string(from: monthStart)
    }

    /// The day numbers for every cell, in the locale's own digits.
    func dayLabels(calendar: Calendar) -> [String] {
        let formatter = Self.formatter(template: "d", calendar: calendar)
        return cells.map { formatter.string(from: $0.start) }
    }

    /// Short weekday names ("Mon") starting on the first weekday, and the
    /// one-letter ones ("M") for when the short ones don't fit a column.
    static func weekdaySymbols(calendar: Calendar) -> (short: [String], narrow: [String]) {
        (ordered(calendar.shortStandaloneWeekdaySymbols, firstWeekday: calendar.firstWeekday),
         ordered(calendar.veryShortStandaloneWeekdaySymbols, firstWeekday: calendar.firstWeekday))
    }

    static func formatter(template: String, calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = calendar.locale ?? .current
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }
}
