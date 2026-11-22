import Foundation

/// "Now", in seconds, for the tools that count minutes (Focus, Breaks).
///
/// DEBUG: `MAXCANDELA_FAST_TIME=60` makes this clock run 60× fast, so a
/// 25-minute focus phase ends in 25 s and a 20-minute break interval in 20 s
/// — the only practical way to hear a transition or see a reminder while
/// testing. Everything measured on it speeds up alike, including the 20 s
/// absence that counts as a break (a third of a second at 60×), so check
/// lock/unlock behaviour at normal speed. Compiled out of release builds.
enum ToolClock {
    static var now: TimeInterval {
        #if DEBUG
        return Date().timeIntervalSinceReferenceDate * speed
        #else
        return Date().timeIntervalSinceReferenceDate
        #endif
    }

    #if DEBUG
    private static let speed: Double = {
        let value = ProcessInfo.processInfo.environment["MAXCANDELA_FAST_TIME"].flatMap(Double.init) ?? 1
        return value > 0 ? value : 1
    }()
    #endif
}
