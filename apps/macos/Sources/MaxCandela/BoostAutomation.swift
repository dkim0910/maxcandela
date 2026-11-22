import Foundation

/// The boost, driven from outside the menu: Shortcuts actions
/// (`BoostIntents.swift`) and `maxcandela://boost/on|off|toggle` links
/// (`AppDelegate.application(_:open:)`), so Raycast, Alfred, Focus modes and
/// the Shortcuts app can switch it.
///
/// One router for both, with the same rules as a click
/// (`MenuBarController.setBoostFromAutomation`): turning off is never gated,
/// turning on needs the licence and a display with headroom. Unlike a click it
/// never opens a dialog — an automation can run with nobody watching — so it
/// reports what happened instead.
enum BoostCommand: Equatable {
    case on, off, toggle

    /// `maxcandela://boost/on`, `…/off`, `…/toggle`. Anything else is nil, so a
    /// mistyped link does nothing rather than guessing. Pure, unit-tested.
    init?(url: URL) {
        guard url.scheme?.lowercased() == "maxcandela",
              url.host?.lowercased() == "boost"
        else { return nil }
        switch url.path.lowercased() {
        case "/on": self = .on
        case "/off": self = .off
        case "/toggle": self = .toggle
        default: return nil
        }
    }
}

enum BoostOutcome: Equatable {
    case on, off
    /// No attached display has EDR headroom (a MacBook Air, say).
    case noHeadroom
    /// The trial has ended and Pro is not owned.
    case needsPro

    /// What a Shortcut shows. Unit-tested to stay in step with the cases.
    var message: String {
        switch self {
        case .on: return "The brightness boost is on."
        case .off: return "The brightness boost is off."
        case .noHeadroom: return SupportMessages.noHeadroomMenuLine
        case .needsPro: return "Your MaxCandela trial has ended. Open the ☀️ menu to unlock Pro and switch the boost on."
        }
    }

    var succeeded: Bool { self == .on || self == .off }
}

@MainActor
enum BoostAutomation {
    typealias Handler = @MainActor (BoostCommand) async -> BoostOutcome

    private static var handler: Handler?
    /// Commands that arrived before the menu existed. Launching the app
    /// through a link or a Shortcut can deliver the command before
    /// `applicationDidFinishLaunching` has built the menu.
    private static var waiting: [CheckedContinuation<Handler, Never>] = []

    static func install(_ newHandler: @escaping Handler) {
        handler = newHandler
        let queued = waiting
        waiting.removeAll()
        queued.forEach { $0.resume(returning: newHandler) }
    }

    /// The command before this one, still running or done. Each command waits
    /// for it, so commands finish in the order they arrived.
    ///
    /// Without this, an `on` that is waiting for the licence check could be
    /// overtaken by a later `off`: the `off` would find nothing to switch off,
    /// then the `on` would land — leaving the boost on although the last
    /// command said off. Seen on hardware 2026-11-22: off, on, off, on sent
    /// back to back ran as off, off, on, on.
    private static var previous: Task<BoostOutcome, Never>?

    static func run(_ command: BoostCommand) async -> BoostOutcome {
        await enqueue(command).value
    }

    /// Queues the command behind the previous one *now*, synchronously, so a
    /// burst of links is ordered by arrival rather than by whichever task the
    /// executor happens to start first.
    @discardableResult
    static func enqueue(_ command: BoostCommand) -> Task<BoostOutcome, Never> {
        let before = previous
        let task = Task { @MainActor () -> BoostOutcome in
            _ = await before?.value
            let current: Handler
            if let installed = handler {
                current = installed
            } else {
                current = await withCheckedContinuation { waiting.append($0) }
            }
            let outcome = await current(command)
            NSLog("MaxCandela: automation \(command) → \(outcome)")
            return outcome
        }
        previous = task
        return task
    }
}
