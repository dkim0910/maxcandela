import Foundation

/// "Only at Night" for Warmth: how much of the user's warmth applies at a
/// given time of day, 0…1.
///
/// Fixed hours, deliberately not sunset/sunrise — that needs the user's
/// location (a permission prompt, an entitlement and a privacy-label change)
/// for a feature whose whole point is to be left alone.
///
/// The edges are ramps, not switches: warmth eases in over the first
/// `rampMinutes` of the window and out over the last. A hard table swap at
/// 8 PM sharp would read as the screen suddenly turning orange.
enum WarmthSchedule {
    static let rampMinutes = 30
    private static let day = 24 * 60

    /// Pure, unit-tested. The window runs from `startHour` to `endHour` and
    /// may cross midnight. Equal hours mean "all day".
    static func factor(minuteOfDay: Int, startHour: Int, endHour: Int,
                       ramp: Int = rampMinutes) -> Double {
        let start = startHour * 60
        let length = (((endHour * 60 - start) % day) + day) % day
        guard length > 0 else { return 1 }
        let into = (((minuteOfDay - start) % day) + day) % day
        guard into < length else { return 0 }
        let edge = min(ramp, length / 2)
        guard edge > 0 else { return 1 }
        let rising = Double(into) / Double(edge)
        let falling = Double(length - into) / Double(edge)
        return max(0, min(1, min(rising, falling)))
    }

    static func minuteOfDay(_ date: Date = Date(), calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}
