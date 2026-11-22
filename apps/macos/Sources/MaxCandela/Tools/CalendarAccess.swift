import EventKit

/// The app's one `EKEventStore` and the questions around Calendar access,
/// shared by Next Meeting (`CalendarTool`, the only place that ever *asks*
/// for access) and the Calendar tool's event dots (which only read, and only
/// once access already exists).
///
/// One store, not one per tool: Apple's EKEventStore documentation says to
/// create a single store and keep using it rather than make one per task.
/// Created on first use, so a launch in which neither tool reads events never
/// opens a connection to Calendar.
enum CalendarAccess {
    static let store = EKEventStore()

    /// macOS kills a process that asks for Calendar access without
    /// `NSCalendarsFullAccessUsageDescription`, and a bare `swift run` binary
    /// has no Info.plist to carry it — so both tools stay inert without it.
    static var canAsk: Bool {
        Bundle.main.object(forInfoDictionaryKey: "NSCalendarsFullAccessUsageDescription") != nil
    }

    /// Reading the status never prompts.
    static var status: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    /// The first video-call link in the event's URL, location or notes.
    static func joinURL(for event: EKEvent) -> URL? {
        let text = [event.url?.absoluteString, event.location, event.notes]
            .compactMap { $0 }.joined(separator: "\n")
        return CalendarTool.joinURL(in: text)
    }
}
