import AppKit
import EventKit

/// Next Meeting (Pro): what's coming up on your calendar, in the menu, with
/// one click to join a call. Reads events through EventKit after the user
/// grants Calendar access; nothing is stored and nothing is sent anywhere.
///
/// Requires, and the shipping build has: the
/// `com.apple.security.personal-information.calendars` sandbox entitlement
/// and `NSCalendarsFullAccessUsageDescription` in Info.plist. A bare
/// `swift run` binary has no Info.plist, and macOS **kills** a process that
/// asks for Calendar access without that key — so the tool checks for it and
/// stays inert under `swift run`. Test in `dist/MaxCandela.app`.
///
/// ⚠️ Therefore not exercised at runtime during development.
final class CalendarTool: MenuTool {
    let menuItem = NSMenuItem(title: "Next Meeting", action: nil, keyEquivalent: "")
    var onStatusChange: (() -> Void)?
    var isPro: Bool { true }

    private let submenu = NSMenu()
    /// Shared with the Calendar tool's event dots — see `CalendarAccess`.
    private var store: EKEventStore { CalendarAccess.store }

    init() {
        menuItem.submenu = submenu
        menuItem.symbol("calendar")
        rebuild()
    }

    func menuWillOpen() { rebuild() }

    /// Pure, unit-tested. The first video-call link in an event's text.
    static func joinURL(in text: String) -> URL? {
        let pattern = #"https://[^\s<>"']*(zoom\.us|meet\.google\.com|teams\.microsoft\.com|teams\.live\.com|webex\.com|whereby\.com)[^\s<>"']*"#
        guard let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else { return nil }
        return URL(string: String(text[range]))
    }

    /// Pure, unit-tested. "now", "in 12 min", "in 2 h 05 min".
    static func relativeText(minutes: Int) -> String {
        if minutes <= 0 { return "now" }
        if minutes < 60 { return "in \(minutes) min" }
        return String(format: "in %d h %02d min", minutes / 60, minutes % 60)
    }

    private func rebuild() {
        submenu.removeAllItems()
        menuItem.title = "Next Meeting"

        guard CalendarAccess.canAsk else {
            addNote("Available in the installed app")
            return
        }
        switch CalendarAccess.status {
        case .fullAccess:
            showEvents()
        case .notDetermined:
            let item = NSMenuItem(title: "Allow Calendar Access…", action: #selector(requestAccess), keyEquivalent: "")
            item.target = self
            submenu.addItem(item.symbol("lock.open"))
        default:
            addNote("Calendar access is off")
            let item = NSMenuItem(title: "Open Privacy Settings…", action: #selector(openSettings), keyEquivalent: "")
            item.target = self
            submenu.addItem(item.symbol("gearshape"))
        }
    }

    private func addNote(_ text: String) {
        let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        item.isEnabled = false
        submenu.addItem(item)
    }

    private func showEvents() {
        let now = Date()
        let predicate = store.predicateForEvents(withStart: now.addingTimeInterval(-30 * 60),
                                                 end: now.addingTimeInterval(36 * 3600), calendars: nil)
        let events = store.events(matching: predicate)
            .filter { !$0.isAllDay && $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }
            .prefix(6)
        guard let first = events.first else {
            addNote("Nothing in the next day and a half")
            return
        }
        let minutes = Int((first.startDate.timeIntervalSince(now) / 60).rounded(.up))
        menuItem.title = "Next: \(first.title ?? "Event") \(Self.relativeText(minutes: minutes))"

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let calendar = Calendar.current
        for event in events {
            let day = calendar.isDateInToday(event.startDate) ? "" : "Tomorrow "
            let link = CalendarAccess.joinURL(for: event)
            let title = "\(day)\(formatter.string(from: event.startDate)) — \(event.title ?? "Event")"
            let item = NSMenuItem(title: link == nil ? title : "\(title)   Join", action: #selector(open(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = link
            item.isEnabled = link != nil
            submenu.addItem(item.symbol(link == nil ? "calendar" : "video"))
        }
    }

    @objc private func open(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func requestAccess() {
        NSApp.activate(ignoringOtherApps: true)
        store.requestFullAccessToEvents { _, _ in }
    }

    @objc private func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }
}
