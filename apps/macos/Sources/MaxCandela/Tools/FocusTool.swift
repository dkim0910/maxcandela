import AppKit

/// One focus rhythm: minutes of work, the short break after each work
/// session, and the long break after every fourth. Pure, unit-tested.
struct FocusPreset: Equatable {
    let workMinutes: Int
    let breakMinutes: Int
    /// Three short breaks' worth, capped at half an hour — an hour off after
    /// four 90-minute blocks is a lunch, not a break.
    let longBreakMinutes: Int

    static let all = [
        FocusPreset(workMinutes: 25, breakMinutes: 5, longBreakMinutes: 15),
        FocusPreset(workMinutes: 50, breakMinutes: 10, longBreakMinutes: 30),
        FocusPreset(workMinutes: 90, breakMinutes: 20, longBreakMinutes: 30),
    ]

    /// Every this-many finished work sessions, the break is a long one.
    static let sessionsPerLongBreak = 4

    var menuTitle: String { "\(workMinutes) min Focus · \(breakMinutes) min Break" }

    func duration(of phase: FocusPhase) -> TimeInterval {
        switch phase {
        case .work: return TimeInterval(workMinutes * 60)
        case .shortBreak: return TimeInterval(breakMinutes * 60)
        case .longBreak: return TimeInterval(longBreakMinutes * 60)
        }
    }
}

enum FocusPhase: Equatable {
    case work, shortBreak, longBreak

    /// What the menu bar says — one short word, so it fits beside the icon.
    var statusWord: String { self == .work ? "Focus" : "Break" }
}

/// A running focus session: work → short break → work … with a long break
/// after every fourth work session. Times are plain seconds on whatever
/// clock the caller uses (the tool passes wall-clock seconds), so the
/// whole state machine is pure and unit-tested.
struct FocusSession: Equatable {
    let preset: FocusPreset
    private(set) var phase: FocusPhase = .work
    /// Work sessions finished so far — the cycle counter. A skipped work
    /// session counts: "skip" means "I'm done with this one".
    private(set) var completedWork = 0
    /// When the running phase ends; nil while paused.
    private(set) var endsAt: TimeInterval?
    /// Time left in the phase while paused; nil while running.
    private(set) var pausedRemaining: TimeInterval?

    init(preset: FocusPreset, now: TimeInterval) {
        self.preset = preset
        endsAt = now + preset.duration(of: .work)
    }

    var isPaused: Bool { pausedRemaining != nil }

    func remaining(at now: TimeInterval) -> TimeInterval {
        if let pausedRemaining { return pausedRemaining }
        return max(0, (endsAt ?? now) - now)
    }

    /// Which session of the current set of four this is (work) or follows
    /// (break), 1-based: the "2" in "Focus 2 of 4".
    var sessionInSet: Int {
        let n = FocusPreset.sessionsPerLongBreak
        return phase == .work ? completedWork % n + 1 : (completedWork - 1) % n + 1
    }

    /// The phase that follows `phase`, given how many work sessions are done
    /// *including* the one that just ended.
    static func phase(after phase: FocusPhase, completedWork: Int) -> FocusPhase {
        switch phase {
        case .work:
            return completedWork % FocusPreset.sessionsPerLongBreak == 0 ? .longBreak : .shortBreak
        case .shortBreak, .longBreak:
            return .work
        }
    }

    mutating func pause(at now: TimeInterval) {
        guard !isPaused else { return }
        pausedRemaining = remaining(at: now)
        endsAt = nil
    }

    mutating func resume(at now: TimeInterval) {
        guard let pausedRemaining else { return }
        endsAt = now + pausedRemaining
        self.pausedRemaining = nil
    }

    /// End the current phase now and start the next one, running — also
    /// from a paused phase, since skipping is an explicit "move on".
    mutating func skip(at now: TimeInterval) {
        moveToNextPhase(at: now)
    }

    /// Call on every tick. When the running phase is over, moves to the next
    /// one and returns it. The next phase starts at `now`, not at the old end
    /// time: a Mac that slept through a phase end lands at the start of the
    /// next phase, not halfway into one the user never saw (and it never
    /// cascades through several phases at once).
    @discardableResult
    mutating func advance(at now: TimeInterval) -> FocusPhase? {
        guard let endsAt, now >= endsAt else { return nil }
        moveToNextPhase(at: now)
        return phase
    }

    private mutating func moveToNextPhase(at now: TimeInterval) {
        if phase == .work { completedWork += 1 }
        phase = Self.phase(after: phase, completedWork: completedWork)
        endsAt = now + preset.duration(of: phase)
        pausedRemaining = nil
    }

    /// Beside the status icon: "Focus 24:59", "Break 4:59", "Paused 12:34".
    func statusText(at now: TimeInterval) -> String {
        let time = TimerTool.format(remaining: remaining(at: now))
        return isPaused ? "Paused \(time)" : "\(phase.statusWord) \(time)"
    }

    /// The tool's own row in the menu: "Focus — 24:59", "Focus — break 4:59",
    /// "Focus — 12:34 (paused)".
    func menuTitle(at now: TimeInterval) -> String {
        let time = TimerTool.format(remaining: remaining(at: now))
        let phase = self.phase == .work ? "" : "break "
        return "Focus — \(phase)\(time)" + (isPaused ? " (paused)" : "")
    }

    /// The menu's progress row: "Focus 2 of 4 — 12:34 left",
    /// "Break — 4:59 left", "Long break — 14:59 left (paused)".
    func progressText(at now: TimeInterval) -> String {
        let label: String
        switch phase {
        case .work: label = "Focus \(sessionInSet) of \(FocusPreset.sessionsPerLongBreak)"
        case .shortBreak: label = "Break"
        case .longBreak: label = "Long break"
        }
        let text = "\(label) — \(TimerTool.format(remaining: remaining(at: now))) left"
        return isPaused ? text + " (paused)" : text
    }
}

/// Focus: work/break cycles (25/5, 50/10, 90/20) with a long break after
/// every fourth work session. The countdown sits beside the status icon and
/// each automatic transition plays the Timer's sound — like Timer, no
/// notification permission: the menu bar is the notification.
///
/// A sibling of `TimerTool` rather than a mode of it: a cycle has its own
/// state (phase, counter, pause) that a one-shot countdown does not, and
/// keeping them apart means both can run at once — a tea timer in the
/// middle of a focus block.
final class FocusTool: MenuTool {
    let menuItem = NSMenuItem(title: "Focus", action: nil, keyEquivalent: "")
    var onStatusChange: (() -> Void)?

    private let submenu = NSMenu()
    private var session: FocusSession?
    private var ticker: Timer?

    // Running-state rows, retitled in place by `tick()` (5 Hz while the menu
    // is open — no inserting or removing items there).
    private let progressItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let countItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let pauseItem = NSMenuItem(title: "Pause", action: nil, keyEquivalent: "")
    private let skipItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let stopItem = NSMenuItem(title: "Stop", action: nil, keyEquivalent: "")

    private static var now: TimeInterval { ToolClock.now }

    init() {
        menuItem.submenu = submenu
        menuItem.symbol("brain.head.profile")
        progressItem.isEnabled = false
        countItem.isEnabled = false
        pauseItem.target = self
        pauseItem.action = #selector(pauseOrResume)
        skipItem.target = self
        skipItem.action = #selector(skip)
        skipItem.symbol("forward.end")
        stopItem.target = self
        stopItem.action = #selector(stop)
        stopItem.symbol("stop")
        rebuild()
    }

    var statusText: String? { session?.statusText(at: Self.now) }

    func menuWillOpen() { rebuild() }
    func tick() { updateItems() }
    func shutdown() { stopTicker() }

    private func rebuild() {
        submenu.removeAllItems()
        if session != nil {
            submenu.addItem(progressItem)
            submenu.addItem(countItem)
            submenu.addItem(.separator())
            // Here rather than in updateItems(): pausing always goes through
            // rebuild(), and a 5 Hz path should not remake images.
            pauseItem.symbol(session?.isPaused == true ? "play" : "pause")
            submenu.addItem(pauseItem)
            submenu.addItem(skipItem)
            submenu.addItem(stopItem)
            submenu.addItem(.separator())
        }
        let header = NSMenuItem(title: session == nil ? "Start a Focus Session" : "Start Over", action: nil, keyEquivalent: "")
        header.isEnabled = false
        submenu.addItem(header)
        for (index, preset) in FocusPreset.all.enumerated() {
            let item = NSMenuItem(title: preset.menuTitle, action: #selector(start(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.toolTip = "\(preset.workMinutes) minutes of focus, then a \(preset.breakMinutes)-minute break. Every \(FocusPreset.sessionsPerLongBreak)th break is \(preset.longBreakMinutes) minutes."
            submenu.addItem(item)
        }
        updateItems()
    }

    private func updateItems() {
        guard let session else {
            menuItem.title = "Focus"
            menuItem.state = .off
            return
        }
        let now = Self.now
        menuItem.title = session.menuTitle(at: now)
        menuItem.state = .on
        progressItem.title = session.progressText(at: now)
        countItem.title = "Sessions completed: \(session.completedWork)"
        pauseItem.title = session.isPaused ? "Resume" : "Pause"
        skipItem.title = session.phase == .work ? "Skip to Break" : "Skip to Focus"
    }

    @objc private func start(_ sender: NSMenuItem) {
        session = FocusSession(preset: FocusPreset.all[sender.tag], now: Self.now)
        startTicker()
        changed()
    }

    @objc private func pauseOrResume() {
        guard var session else { return }
        if session.isPaused {
            session.resume(at: Self.now)
            startTicker()
        } else {
            session.pause(at: Self.now)
            // Nothing moves while paused; the status text stays as it is.
            stopTicker()
        }
        self.session = session
        changed()
    }

    @objc private func skip() {
        guard var session else { return }
        session.skip(at: Self.now)
        self.session = session
        // No sound: the sound tells someone who isn't looking that a phase
        // changed, and whoever clicked Skip is looking.
        startTicker()
        changed()
    }

    @objc private func stop() {
        session = nil
        stopTicker()
        changed()
    }

    private func changed() {
        rebuild()
        onStatusChange?()
    }

    private func startTicker() {
        ticker?.invalidate()
        // .common so the countdown keeps moving while a menu is open.
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.second()
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func second() {
        guard var session else { return stopTicker() }
        if session.advance(at: Self.now) != nil {
            // Same sound as the Timer, at every work ↔ break change.
            NSSound(named: "Glass")?.play()
        }
        self.session = session
        updateItems()
        onStatusChange?()
    }
}
