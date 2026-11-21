import AppKit
import IOKit.pwr_mgt

/// Keep Awake: stop the display (and so the Mac) idle-sleeping, for a set time
/// or until switched off. A public IOKit power assertion — the same mechanism
/// a video player uses — which the system drops by itself if the app exits.
final class KeepAwakeTool: MenuTool {
    let menuItem = NSMenuItem(title: "Keep Awake", action: nil, keyEquivalent: "")
    var onStatusChange: (() -> Void)?

    private let submenu = NSMenu()
    private var assertionID: IOPMAssertionID = 0
    private(set) var isActive = false
    /// nil while active == "until I turn it off".
    private var endDate: Date?
    private var expiryTimer: Timer?

    /// Minutes; 0 == indefinitely.
    private static let durations = [30, 60, 120, 240, 0]

    init() {
        menuItem.submenu = submenu
        menuItem.symbol("cup.and.saucer")
        rebuild()
    }

    /// Pure, unit-tested.
    static func durationTitle(minutes: Int) -> String {
        switch minutes {
        case 0: return "Until I Turn It Off"
        case ..<60: return "For \(minutes) Minutes"
        case 60: return "For 1 Hour"
        default: return "For \(minutes / 60) Hours"
        }
    }

    /// Pure, unit-tested. "1 h 05 min left", "12 min left", "under a minute left".
    static func remainingText(seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes >= 60 { return String(format: "%d h %02d min left", minutes / 60, minutes % 60) }
        if minutes >= 1 { return "\(minutes) min left" }
        return "under a minute left"
    }

    func menuWillOpen() { rebuild() }
    func tick() { updateTitle() }
    func shutdown() { stop() }

    private func rebuild() {
        submenu.removeAllItems()
        let off = NSMenuItem(title: "Off", action: #selector(turnOff), keyEquivalent: "")
        off.target = self
        off.state = isActive ? .off : .on
        submenu.addItem(off)
        submenu.addItem(.separator())
        for minutes in Self.durations {
            let item = NSMenuItem(title: Self.durationTitle(minutes: minutes),
                                  action: #selector(start(_:)), keyEquivalent: "")
            item.target = self
            item.tag = minutes
            submenu.addItem(item)
        }
        updateTitle()
    }

    private func updateTitle() {
        menuItem.state = isActive ? .on : .off
        guard isActive else {
            menuItem.title = "Keep Awake"
            return
        }
        if let endDate {
            menuItem.title = "Keep Awake — \(Self.remainingText(seconds: endDate.timeIntervalSinceNow))"
        } else {
            menuItem.title = "Keep Awake — on"
        }
    }

    @objc private func start(_ sender: NSMenuItem) {
        stop()
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "MaxCandela Keep Awake" as CFString, &id)
        guard result == kIOReturnSuccess else {
            NSLog("MaxCandela: keep-awake assertion refused (%d)", result)
            return
        }
        assertionID = id
        isActive = true
        if sender.tag > 0 {
            let end = Date().addingTimeInterval(TimeInterval(sender.tag * 60))
            endDate = end
            let timer = Timer(fire: end, interval: 0, repeats: false) { [weak self] _ in
                self?.stop()
            }
            RunLoop.main.add(timer, forMode: .common)
            expiryTimer = timer
        }
        updateTitle()
    }

    @objc private func turnOff() { stop() }

    private func stop() {
        expiryTimer?.invalidate()
        expiryTimer = nil
        endDate = nil
        if isActive {
            IOPMAssertionRelease(assertionID)
            isActive = false
        }
        updateTitle()
    }
}
