import AppKit

/// A countdown timer that shows its remaining time next to the status icon
/// and plays a sound when it ends. No notification permission involved — the
/// menu bar *is* the notification.
final class TimerTool: MenuTool {
    let menuItem = NSMenuItem(title: "Timer", action: nil, keyEquivalent: "")
    var onStatusChange: (() -> Void)?

    private let submenu = NSMenu()
    private var endDate: Date?
    private var ticker: Timer?
    /// Shown briefly after the timer ends.
    private var finishedUntil: Date?

    private static let presets = [5, 10, 15, 25, 45, 60]

    init() {
        menuItem.submenu = submenu
        menuItem.symbol("timer")
        rebuild()
    }

    /// Pure, unit-tested. "24:59", "1:05:00"; never negative.
    static func format(remaining: TimeInterval) -> String {
        let total = max(0, Int(remaining.rounded(.up)))
        let (h, m, s) = (total / 3600, (total % 3600) / 60, total % 60)
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    var statusText: String? {
        if let endDate { return Self.format(remaining: endDate.timeIntervalSinceNow) }
        if let finishedUntil, Date() < finishedUntil { return "Time’s up" }
        return nil
    }

    func menuWillOpen() { rebuild() }
    func tick() { updateTitle() }
    func shutdown() { ticker?.invalidate() }

    private func rebuild() {
        submenu.removeAllItems()
        if endDate != nil {
            let cancel = NSMenuItem(title: "Cancel Timer", action: #selector(cancel), keyEquivalent: "")
            cancel.target = self
            submenu.addItem(cancel)
            submenu.addItem(.separator())
        }
        for minutes in Self.presets {
            let item = NSMenuItem(title: "\(minutes) Minutes", action: #selector(start(_:)), keyEquivalent: "")
            item.target = self
            item.tag = minutes
            submenu.addItem(item)
        }
        updateTitle()
    }

    private func updateTitle() {
        if let endDate {
            menuItem.title = "Timer — \(Self.format(remaining: endDate.timeIntervalSinceNow))"
            menuItem.state = .on
        } else {
            menuItem.title = "Timer"
            menuItem.state = .off
        }
    }

    @objc private func start(_ sender: NSMenuItem) {
        endDate = Date().addingTimeInterval(TimeInterval(sender.tag * 60))
        finishedUntil = nil
        startTicker()
        updateTitle()
        onStatusChange?()
    }

    @objc private func cancel() {
        endDate = nil
        ticker?.invalidate()
        ticker = nil
        updateTitle()
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

    private func second() {
        if let endDate, endDate.timeIntervalSinceNow <= 0 {
            self.endDate = nil
            finishedUntil = Date().addingTimeInterval(15)
            NSSound(named: "Glass")?.play()
            updateTitle()
        } else if endDate == nil, finishedUntil.map({ Date() >= $0 }) ?? true {
            // "Time's up" has been shown long enough; nothing left to count.
            finishedUntil = nil
            ticker?.invalidate()
            ticker = nil
        }
        onStatusChange?()
    }
}
