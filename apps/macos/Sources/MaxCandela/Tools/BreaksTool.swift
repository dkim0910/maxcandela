import AppKit

/// Why the user is not looking at the screen right now.
enum AwayReason: CaseIterable {
    case locked, screenSaver, displayAsleep, asleep, switchedUser
}

/// Screen time since the last break, counted from the system's own
/// "the user stepped away" events rather than from input. Pure, unit-tested;
/// times are plain seconds on whatever clock the caller uses (the tool
/// passes wall-clock seconds, so a sleep's length is measured too).
///
/// - Time counts while no `AwayReason` is active.
/// - Away reasons overlap (lock → display sleeps → display wakes → unlock),
///   so the user is back only when the last one ends.
/// - An absence at least as long as the break itself *is* the break: the
///   count starts again from zero. A shorter one only pauses it.
struct BreakClock: Equatable {
    /// Seconds of screen time between reminders.
    var interval: TimeInterval
    /// The 20 in 20-20-20: how long the reminder lasts, and the shortest
    /// absence that counts as having taken a break.
    static let breakLength: TimeInterval = 20

    /// Screen time from stretches that have ended.
    private(set) var banked: TimeInterval = 0
    /// Start of the current stretch at the screen; nil while away.
    private(set) var presentSince: TimeInterval?
    /// When the current absence began; nil while present.
    private(set) var awaySince: TimeInterval?
    private(set) var reasons: Set<AwayReason> = []

    init(interval: TimeInterval, now: TimeInterval) {
        self.interval = interval
        presentSince = now
    }

    var isAway: Bool { !reasons.isEmpty }

    func used(at now: TimeInterval) -> TimeInterval {
        // max(0, …): a clock set backwards must not subtract screen time.
        banked + (presentSince.map { max(0, now - $0) } ?? 0)
    }

    func remaining(at now: TimeInterval) -> TimeInterval {
        max(0, interval - used(at: now))
    }

    /// Time to show the reminder — never to someone who is away, even if the
    /// count reached the interval just as they left.
    func shouldRemind(at now: TimeInterval) -> Bool {
        !isAway && used(at: now) >= interval
    }

    mutating func away(_ reason: AwayReason, at now: TimeInterval) {
        if reasons.isEmpty {
            banked = used(at: now)
            presentSince = nil
            awaySince = now
        }
        reasons.insert(reason)
    }

    mutating func back(_ reason: AwayReason, at now: TimeInterval) {
        guard reasons.remove(reason) != nil, reasons.isEmpty else { return }
        endAbsence(at: now)
    }

    /// Clear every away reason at once: the user is evidently here (they
    /// opened our menu), whatever we believed. Guards against a "back" event
    /// that never arrived leaving the count paused forever.
    mutating func backFromEverything(at now: TimeInterval) {
        guard !reasons.isEmpty else { return }
        reasons.removeAll()
        endAbsence(at: now)
    }

    /// The Mac woke from sleep. Ends every absence (the lock screen that
    /// follows is a few seconds, not worth a reason that could get stuck).
    /// If we never heard it go to sleep, the sleep still was a break.
    mutating func woke(at now: TimeInterval) {
        if reasons.isEmpty {
            restart(at: now)
        } else {
            backFromEverything(at: now)
        }
    }

    /// A break was taken or skipped: count from zero again. An absence in
    /// progress stays in progress — the reminder can finish while the user
    /// is at the lock screen, and their return must still end it.
    mutating func restart(at now: TimeInterval) {
        banked = 0
        if presentSince != nil { presentSince = now }
    }

    /// Remind again after `seconds` more screen time.
    mutating func snooze(for seconds: TimeInterval, at now: TimeInterval) {
        banked = max(0, interval - seconds)
        if presentSince != nil { presentSince = now }
    }

    private mutating func endAbsence(at now: TimeInterval) {
        if let awaySince, now - awaySince >= Self.breakLength { banked = 0 }
        awaySince = nil
        presentSince = now
    }
}

/// Breaks: a 20-20-20 reminder. After N minutes of screen time (20/30/45/60;
/// off by default) a small panel near the top of the screen says to look at
/// something 20 feet away, counts down 20 seconds and closes itself. It
/// never takes focus — typing carries on into the front app. No
/// notification permission.
///
/// **What counts as screen time, and why not input idle time.** The obvious
/// tool, `CGEventSourceSecondsSinceLastEventType`, was ruled out. No Apple
/// document or DTS answer says whether it is gated by Input Monitoring in a
/// sandboxed app (researched 2026-11-22: only unsandboxed third-party
/// projects report "no prompt"), and a prompt is not acceptable here. It is
/// also the wrong measure for eye strain: reading or watching a video is
/// screen time with no input at all. So time counts while the screen is in
/// use, and stops on the system's own away events:
///  - screen locked / unlocked (`com.apple.screenIsLocked` / `…Unlocked`,
///    distributed notifications),
///  - screen saver started / stopped (`com.apple.screensaver.didstart` /
///    `…didstop`),
///  - display sleep / wake — this includes the idle display sleep from
///    System Settings, which is what catches a user who simply walked away
///    (video players hold the display awake, correctly counting as use),
///  - system sleep / wake and fast user switching (`NSWorkspace`).
/// An absence of 20 s or more counts as the break. The idle minutes before
/// the display sleeps do count as use — the granularity this costs.
///
/// The notification names above are long-standing system strings, not
/// documented API; observing them uses only public `DistributedNotificationCenter`.
final class BreaksTool: MenuTool {
    let menuItem = NSMenuItem(title: "Breaks", action: nil, keyEquivalent: "")
    var onStatusChange: (() -> Void)?

    static let choices = [20, 30, 45, 60]
    static let snoozeMinutes = 5
    private static let minutesKey = "com.maxcandela.breaks.minutes"

    private let submenu = NSMenu()
    private let nextItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    /// nil while reminders are off.
    private var clock: BreakClock?
    private var checkTimer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    /// Built on first reminder.
    private var panel: BreakPanel?

    /// Minutes between reminders; 0 == off (the default).
    private var minutes: Int {
        get { UserDefaults.standard.integer(forKey: Self.minutesKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.minutesKey) }
    }

    private static var now: TimeInterval { ToolClock.now }

    init() {
        menuItem.submenu = submenu
        menuItem.symbol("eye")
        nextItem.isEnabled = false
        if Self.choices.contains(minutes) { turnOn() } else if minutes != 0 { minutes = 0 }
        rebuild()
    }

    /// Pure, unit-tested. "Next break in 12 min", "Next break in under a minute".
    static func nextBreakText(remaining: TimeInterval, away: Bool) -> String {
        if away { return "Paused while you’re away" }
        let minutes = Int((remaining / 60).rounded(.up))
        return remaining < 60 ? "Next break in under a minute" : "Next break in \(minutes) min"
    }

    func menuWillOpen() {
        // Someone opening our menu is at the screen, whatever we believed.
        if clock?.isAway == true { record("menu opened") { $0.backFromEverything(at: $1) } }
        rebuild()
    }

    func tick() { updateNext() }

    func shutdown() { turnOff() }

    deinit {
        // The distributed centre does not retain observers; never leave it
        // holding a dangling one.
        DistributedNotificationCenter.default().removeObserver(self)
    }

    // MARK: - Menu

    private func rebuild() {
        submenu.removeAllItems()
        let off = NSMenuItem(title: "Off", action: #selector(choose(_:)), keyEquivalent: "")
        off.target = self
        off.tag = 0
        off.state = minutes == 0 ? .on : .off
        submenu.addItem(off)
        submenu.addItem(.separator())
        for choice in Self.choices {
            let item = NSMenuItem(title: "Every \(choice) Minutes", action: #selector(choose(_:)), keyEquivalent: "")
            item.target = self
            item.tag = choice
            item.state = minutes == choice ? .on : .off
            item.toolTip = "After \(choice) minutes of screen time, a reminder to look at something 20 feet away for 20 seconds. Locking the screen, the screen saver or sleep for 20 seconds or more counts as a break."
            submenu.addItem(item)
        }
        if clock != nil {
            submenu.addItem(.separator())
            submenu.addItem(nextItem)
            let now = NSMenuItem(title: "Take a Break Now", action: #selector(breakNow), keyEquivalent: "")
            now.target = self
            submenu.addItem(now.symbol("eye"))
        }
        updateNext()
    }

    private func updateNext() {
        menuItem.state = clock == nil ? .off : .on
        menuItem.title = clock == nil ? "Breaks" : "Breaks — every \(minutes) min"
        guard let clock else { return }
        let now = Self.now
        nextItem.title = Self.nextBreakText(remaining: clock.remaining(at: now), away: clock.isAway)
    }

    @objc private func choose(_ sender: NSMenuItem) {
        minutes = sender.tag
        if sender.tag == 0 {
            turnOff()
        } else if clock == nil {
            turnOn()
        } else {
            // A new interval keeps the screen time already counted.
            clock?.interval = TimeInterval(sender.tag * 60)
            check()
        }
        rebuild()
    }

    @objc private func breakNow() { remind() }

    // MARK: - Counting

    private func turnOn() {
        clock = BreakClock(interval: TimeInterval(minutes * 60), now: Self.now)
        observe()
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in self?.check() }
        timer.tolerance = 2
        // .common: a reminder is due whether or not a menu happens to be open.
        RunLoop.main.add(timer, forMode: .common)
        checkTimer = timer
    }

    private func turnOff() {
        clock = nil
        checkTimer?.invalidate()
        checkTimer = nil
        stopObserving()
        panel?.close()
    }

    private func check() {
        guard let clock, panel?.isShowing != true, clock.shouldRemind(at: Self.now) else { return }
        remind()
    }

    private static let screenLocked = Notification.Name("com.apple.screenIsLocked")
    private static let screenUnlocked = Notification.Name("com.apple.screenIsUnlocked")
    private static let saverStarted = Notification.Name("com.apple.screensaver.didstart")
    private static let saverStopped = Notification.Name("com.apple.screensaver.didstop")

    private func observe() {
        // AppKit suspends distributed-notification delivery while the app is
        // not active — and an accessory app almost never is — queueing only
        // the last of each name until it is. A lock and its unlock would
        // then arrive together, whenever the user next clicked our menu.
        // `.deliverImmediately` opts these four out of that.
        let distributed = DistributedNotificationCenter.default()
        for (name, selector) in [(Self.screenLocked, #selector(screenLocked(_:))),
                                 (Self.screenUnlocked, #selector(screenUnlocked(_:))),
                                 (Self.saverStarted, #selector(saverStarted(_:))),
                                 (Self.saverStopped, #selector(saverStopped(_:)))] {
            distributed.addObserver(self, selector: selector, name: name, object: nil,
                                    suspensionBehavior: .deliverImmediately)
        }

        let workspace = NSWorkspace.shared.notificationCenter
        let pairs: [(away: Notification.Name, back: Notification.Name, reason: AwayReason)] = [
            (NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification, .displayAsleep),
            (NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.sessionDidBecomeActiveNotification, .switchedUser),
        ]
        // queue: .main, so these run synchronously on arrival — willSleep in
        // particular must be recorded before the Mac sleeps, not after it wakes.
        for pair in pairs {
            let reason = pair.reason
            workspaceObservers.append(workspace.addObserver(forName: pair.away, object: nil, queue: .main) { [weak self] note in
                self?.record(note.name.rawValue) { $0.away(reason, at: $1) }
            })
            workspaceObservers.append(workspace.addObserver(forName: pair.back, object: nil, queue: .main) { [weak self] note in
                self?.record(note.name.rawValue) { $0.back(reason, at: $1) }
            })
        }
        workspaceObservers.append(workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] note in
            self?.record(note.name.rawValue) { $0.away(.asleep, at: $1) }
        })
        workspaceObservers.append(workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] note in
            self?.record(note.name.rawValue) { $0.woke(at: $1) }
        })
    }

    private func stopObserving() {
        DistributedNotificationCenter.default().removeObserver(self)
        let workspace = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach(workspace.removeObserver)
        workspaceObservers.removeAll()
    }

    @objc private func screenLocked(_ note: Notification) { record(note.name.rawValue) { $0.away(.locked, at: $1) } }
    @objc private func screenUnlocked(_ note: Notification) { record(note.name.rawValue) { $0.back(.locked, at: $1) } }
    @objc private func saverStarted(_ note: Notification) { record(note.name.rawValue) { $0.away(.screenSaver, at: $1) } }
    @objc private func saverStopped(_ note: Notification) { record(note.name.rawValue) { $0.back(.screenSaver, at: $1) } }

    /// Every away/back event goes through here. Timestamped on arrival; the
    /// clock is main-thread state, so an event delivered on another thread
    /// (the distributed centre makes no promise) is applied on main with the
    /// time it actually happened. DEBUG logs each one — on hardware that is
    /// the only way to tell an event arrived, rather than the menu-open
    /// safety net having covered for it: `log stream --predicate
    /// 'eventMessage CONTAINS "MaxCandela breaks"'`.
    private func record(_ event: String, _ change: @escaping (inout BreakClock, TimeInterval) -> Void) {
        let now = Self.now
        let apply = { [weak self] in
            guard let self, var clock = self.clock else { return }
            change(&clock, now)
            self.clock = clock
            #if DEBUG
            NSLog("MaxCandela breaks: %@ → %@, %.0f s of screen time counted",
                  event, clock.isAway ? "away" : "present", clock.used(at: now))
            #endif
        }
        if Thread.isMainThread { apply() } else { DispatchQueue.main.async(execute: apply) }
    }

    // MARK: - Reminder

    private func remind() {
        let reminder = panel ?? BreakPanel()
        panel = reminder
        reminder.onFinish = { [weak self] in self?.clock?.restart(at: Self.now) }
        reminder.onSkip = { [weak self] in self?.clock?.restart(at: Self.now) }
        reminder.onSnooze = { [weak self] in
            self?.clock?.snooze(for: TimeInterval(Self.snoozeMinutes * 60), at: Self.now)
        }
        reminder.show(seconds: Int(BreakClock.breakLength), snoozeMinutes: Self.snoozeMinutes)
    }
}
