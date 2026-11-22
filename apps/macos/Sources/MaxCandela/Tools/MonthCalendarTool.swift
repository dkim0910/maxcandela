import AppKit
import EventKit

/// Calendar: this month as a grid inside the menu, with ISO week numbers and
/// the date beside the status icon as options (both off by default).
///
/// Free: the grid. It never touches EventKit — no read, no access check, no
/// prompt — so it is the same whether Calendar access was granted, refused or
/// never asked for. First weekday, weekday names, month names and digits all
/// come from the user's `Calendar.current` and its locale.
///
/// Pro (`ProGate`): a dot under each day that has events, and the clicked
/// day's events (time, title, Join for a video-call link) listed under the
/// grid. Only when Calendar access was *already* granted: this tool never
/// asks. Next Meeting (`CalendarTool`) is the one place that does, and both
/// read through the one shared store (`CalendarAccess`). Events are read when
/// this submenu opens, not when the main menu does, so opening the menu for
/// something else never queries the calendar.
///
/// Month maths, week numbers and event bucketing are pure and tested
/// (`MonthLayout`, `MonthGridGeometry`). Unverified, because only a real Mac
/// shows it: that ‹ / Today / › and day clicks keep the menu open
/// (`MonthGridView`); that the events list grows and shrinks inside the open
/// menu cleanly; and the dots themselves, which need the installed build —
/// EventKit is inert under `swift run` (see CalendarTool).
final class MonthCalendarTool: MenuTool {
    let menuItem = NSMenuItem(title: "Calendar", action: nil, keyEquivalent: "")
    /// MenuBarController sets this after init; a date switched on in an
    /// earlier session is published then, not at the first menu open.
    var onStatusChange: (() -> Void)? {
        didSet { if statusText != nil { onStatusChange?() } }
    }
    /// Cached rather than computed: MenuBarController reads every tool's
    /// status whenever any one changes, which is every second while a timer
    /// counts down.
    private(set) var statusText: String?

    private static let weekNumbersKey = "com.maxcandela.calendar.weekNumbers"
    private static let dateKey = "com.maxcandela.calendar.dateInMenuBar"
    /// A short list; a busy day belongs in Calendar itself.
    static let maxEventRows = 8

    private let submenu = NSMenu()
    private let grid: MonthGridView
    private let eventsSeparator = NSMenuItem.separator()
    /// The rows between `eventsSeparator` and the options, replaced in place
    /// (also while the menu is open, when a day is clicked).
    private var eventItems: [NSMenuItem] = []
    private let weekNumbersItem = NSMenuItem(title: "Show Week Numbers", action: nil, keyEquivalent: "")
    private let dateItem = NSMenuItem(title: "Show Date in Menu Bar", action: nil, keyEquivalent: "")
    private let opener: SubmenuOpener

    /// Taken afresh at every menu open, so a changed first weekday, time zone
    /// or region shows without a relaunch.
    private var calendar: Calendar
    private var today: Date
    private var selectedDay: Date?
    private var layout: MonthLayout
    /// Pro: the events in the visible grid, read when the submenu opens.
    private var events: [EKEvent] = []
    private var observers: [(center: NotificationCenter, token: NSObjectProtocol)] = []

    private var showsWeekNumbers: Bool {
        get { UserDefaults.standard.bool(forKey: Self.weekNumbersKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.weekNumbersKey) }
    }

    private var showsDate: Bool {
        get { UserDefaults.standard.bool(forKey: Self.dateKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.dateKey) }
    }

    init() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let layout = MonthLayout(containing: today, calendar: calendar)
        self.calendar = calendar
        self.today = today
        self.selectedDay = today
        self.layout = layout
        grid = MonthGridView(model: Self.model(layout: layout, calendar: calendar, today: today, selected: today,
                                               eventDays: [], showsWeekNumbers: false))
        opener = SubmenuOpener()

        menuItem.submenu = submenu
        menuItem.symbol("calendar")
        // Explicit enabling, so the grid's action-less item is never
        // auto-disabled; every row below sets its own state.
        submenu.autoenablesItems = false
        submenu.delegate = opener
        opener.onOpen = { [weak self] in self?.submenuWillOpen() }

        let gridItem = NSMenuItem()
        gridItem.view = grid
        submenu.addItem(gridItem)
        submenu.addItem(eventsSeparator)
        submenu.addItem(.separator())
        weekNumbersItem.target = self
        weekNumbersItem.action = #selector(toggleWeekNumbers)
        weekNumbersItem.toolTip = "ISO 8601 week numbers: weeks run Monday to Sunday, and week 1 is the one with the year's first Thursday."
        submenu.addItem(weekNumbersItem.symbol("number"))
        dateItem.target = self
        dateItem.action = #selector(toggleDate)
        submenu.addItem(dateItem.symbol("menubar.rectangle"))

        grid.onPrevious = { [weak self] in self?.page(by: -1) }
        grid.onNext = { [weak self] in self?.page(by: 1) }
        grid.onToday = { [weak self] in self?.goToToday() }
        grid.onSelect = { [weak self] in self?.select(cell: $0) }

        observeDayChanges()
        updateStatus()
        menuWillOpen()
    }

    // MARK: - MenuTool

    /// Every open starts on today. Nothing is read from EventKit here.
    func menuWillOpen() {
        calendar = Calendar.current
        today = calendar.startOfDay(for: Date())
        selectedDay = today
        events = []
        weekNumbersItem.state = showsWeekNumbers ? .on : .off
        dateItem.state = showsDate ? .on : .off
        show(month: today, loadingEvents: false)
    }

    /// Midnight while the menu is open moves the today mark.
    func tick() {
        let now = calendar.startOfDay(for: Date())
        guard now != today else { return }
        today = now
        pushModel()
        updateStatus()
    }

    func shutdown() {
        observers.forEach { $0.center.removeObserver($0.token) }
        observers = []
    }

    // MARK: - Pure, unit-tested

    /// "Sun, Nov 22" in the user's locale — short enough for the menu bar.
    static func statusText(for date: Date, calendar: Calendar) -> String {
        MonthLayout.formatter(template: "EEEMMMd", calendar: calendar).string(from: date)
    }

    /// The heading over a day's events: "Today", else the weekday and date,
    /// with the year only when it is not the current one.
    static func dayHeading(for day: Date, today: Date, calendar: Calendar) -> String {
        if calendar.isDate(day, inSameDayAs: today) { return "Today" }
        let sameYear = calendar.component(.year, from: day) == calendar.component(.year, from: today)
        return MonthLayout.formatter(template: sameYear ? "EEEEMMMMd" : "EEEEMMMMdy", calendar: calendar).string(from: day)
    }

    /// The time shown in front of an event on a given day: its start; "All
    /// day" for all-day events and for timed ones that cover the whole day;
    /// "until …" for one that began on an earlier day and ends on this one.
    static func timeText(_ span: EventSpan, isAllDay: Bool, dayStart: Date, dayEnd: Date,
                         formatter: DateFormatter) -> String {
        if isAllDay { return "All day" }
        if span.start < dayStart {
            return span.end < dayEnd ? "until \(formatter.string(from: span.end))" : "All day"
        }
        return formatter.string(from: span.start)
    }

    // MARK: - Grid

    private static func model(layout: MonthLayout, calendar: Calendar, today: Date, selected: Date?,
                              eventDays: Set<Int>, showsWeekNumbers: Bool) -> MonthGridView.Model {
        let symbols = MonthLayout.weekdaySymbols(calendar: calendar)
        return MonthGridView.Model(
            layout: layout,
            title: MonthLayout.title(for: layout.monthStart, calendar: calendar),
            weekdaySymbols: symbols.short,
            narrowWeekdaySymbols: symbols.narrow,
            dayLabels: layout.dayLabels(calendar: calendar),
            todayIndex: layout.index(containing: today),
            selectedIndex: selected.flatMap(layout.index(containing:)),
            eventDays: eventDays,
            showsWeekNumbers: showsWeekNumbers)
    }

    private func pushModel() {
        grid.model = Self.model(layout: layout, calendar: calendar, today: today, selected: selectedDay,
                                eventDays: layout.eventDays(events.compactMap(Self.span)),
                                showsWeekNumbers: showsWeekNumbers)
    }

    private func show(month: Date, loadingEvents: Bool) {
        layout = MonthLayout(containing: month, calendar: calendar)
        if loadingEvents { loadEvents() }
        pushModel()
        rebuildEventRows()
    }

    private func page(by months: Int) {
        guard let month = calendar.date(byAdding: .month, value: months, to: layout.monthStart) else { return }
        selectedDay = nil
        show(month: month, loadingEvents: true)
    }

    private func goToToday() {
        today = calendar.startOfDay(for: Date())
        selectedDay = today
        show(month: today, loadingEvents: true)
    }

    private func select(cell index: Int) {
        guard layout.cells.indices.contains(index) else { return }
        let cell = layout.cells[index]
        selectedDay = cell.start
        if cell.isInMonth {
            pushModel()
            rebuildEventRows()
        } else {
            // A dimmed day belongs to the month before or after: go there.
            show(month: cell.start, loadingEvents: true)
        }
    }

    /// The submenu is about to appear — the moment to read events.
    private func submenuWillOpen() {
        loadEvents()
        pushModel()
        rebuildEventRows()
    }

    // MARK: - Events (Pro)

    private enum EventSource {
        case locked, notInstalled, notAllowed, denied, readable
    }

    /// Reads only the authorisation *status*, which never prompts.
    private var eventSource: EventSource {
        guard ProGate.shared.isAllowed else { return .locked }
        guard CalendarAccess.canAsk else { return .notInstalled }
        switch CalendarAccess.status {
        case .fullAccess: return .readable
        case .notDetermined: return .notAllowed
        default: return .denied
        }
    }

    private func loadEvents() {
        guard eventSource == .readable else {
            events = []
            return
        }
        let range = layout.interval
        let store = CalendarAccess.store
        events = store.events(matching: store.predicateForEvents(withStart: range.start, end: range.end, calendars: nil))
    }

    private static func span(of event: EKEvent) -> EventSpan? {
        guard let start = event.startDate, let end = event.endDate else { return nil }
        return EventSpan(start: start, end: end)
    }

    private func rebuildEventRows() {
        eventItems.forEach(submenu.removeItem)
        eventItems = makeEventRows()
        let first = submenu.index(of: eventsSeparator) + 1
        for (offset, item) in eventItems.enumerated() {
            submenu.insertItem(item, at: first + offset)
        }
    }

    private func makeEventRows() -> [NSMenuItem] {
        switch eventSource {
        case .locked:
            // Same convention as the main menu's locked Pro tools: a
            // clickable "— Pro" row that opens the paywall.
            let item = NSMenuItem(title: "Events — Pro", action: #selector(upgrade), keyEquivalent: "")
            item.target = self
            return [item.symbol("calendar.badge.clock")]
        case .notInstalled:
            return [note("Events: available in the installed app")]
        case .notAllowed:
            return [note("Events: allow Calendar access in Next Meeting")]
        case .denied:
            return [note("Events: Calendar access is off")]
        case .readable:
            guard let selectedDay, let index = layout.index(containing: selectedDay) else {
                return [note("Click a day to see its events")]
            }
            return eventRows(forCell: index)
        }
    }

    private func eventRows(forCell index: Int) -> [NSMenuItem] {
        let dayStart = layout.boundaries[index], dayEnd = layout.boundaries[index + 1]
        var rows = [NSMenuItem.sectionHeader(title: Self.dayHeading(for: dayStart, today: today, calendar: calendar))]
        let onDay: [(event: EKEvent, span: EventSpan)] = events.compactMap { event in
            guard let span = Self.span(of: event), layout.span(span, fallsOn: index) else { return nil }
            return (event, span)
        }.sorted { a, b in
            // All-day first, then by start time.
            a.event.isAllDay != b.event.isAllDay ? a.event.isAllDay : a.span.start < b.span.start
        }
        guard !onDay.isEmpty else { return rows + [note("No events")] }

        let formatter = DateFormatter()
        formatter.locale = calendar.locale ?? .current
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        for (event, span) in onDay.prefix(Self.maxEventRows) {
            let link = CalendarAccess.joinURL(for: event)
            let when = Self.timeText(span, isAllDay: event.isAllDay, dayStart: dayStart, dayEnd: dayEnd, formatter: formatter)
            let name = ClipboardHistory.menuTitle(for: event.title ?? "")
            let title = "\(when) — \(name.isEmpty ? "Event" : name)"
            let item = NSMenuItem(title: link == nil ? title : "\(title)   Join", action: #selector(open(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = link
            // As in Next Meeting: only a row with a call to join does anything.
            item.isEnabled = link != nil
            rows.append(item.symbol(link == nil ? "calendar" : "video"))
        }
        if onDay.count > Self.maxEventRows {
            rows.append(note("\(onDay.count - Self.maxEventRows) more in Calendar"))
        }
        return rows
    }

    private func note(_ text: String) -> NSMenuItem {
        let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func open(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func upgrade() {
        ProGate.shared.requestUpgrade()
    }

    // MARK: - Options

    @objc private func toggleWeekNumbers() {
        showsWeekNumbers.toggle()
        weekNumbersItem.state = showsWeekNumbers ? .on : .off
        pushModel()
    }

    @objc private func toggleDate() {
        showsDate.toggle()
        dateItem.state = showsDate ? .on : .off
        updateStatus()
    }

    // MARK: - Date in the menu bar

    private func updateStatus() {
        let text = showsDate ? Self.statusText(for: Date(), calendar: .current) : nil
        guard text != statusText else { return }
        statusText = text
        onStatusChange?()
    }

    /// The date beside the icon must turn over at midnight with no menu open
    /// and no timer: Foundation posts `NSCalendarDayChanged` for exactly that.
    /// Wake, a clock or time-zone change, and a region change are covered too.
    private func observeDayChanges() {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            .NSCalendarDayChanged, .NSSystemClockDidChange,
            .NSSystemTimeZoneDidChange, NSLocale.currentLocaleDidChangeNotification,
        ]
        for name in names {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                // The system zone is cached per process until reset.
                if note.name == .NSSystemTimeZoneDidChange { NSTimeZone.resetSystemTimeZone() }
                self?.updateStatus()
            }
            observers.append((center, token))
        }
        let workspace = NSWorkspace.shared.notificationCenter
        let token = workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.updateStatus()
        }
        observers.append((workspace, token))
    }
}

/// `NSMenuDelegate` needs an NSObject; the tool is not one. Its submenu
/// tells it here when it is about to be shown.
private final class SubmenuOpener: NSObject, NSMenuDelegate {
    var onOpen: () -> Void = {}

    func menuNeedsUpdate(_ menu: NSMenu) { onOpen() }
}
