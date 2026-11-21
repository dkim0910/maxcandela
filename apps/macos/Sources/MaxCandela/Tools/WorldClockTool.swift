import AppKit

/// World Clock: the time in a few cities, live while the menu is open.
/// Clicking a row copies it; the Cities submenu chooses which are shown.
final class WorldClockTool: MenuTool {
    let menuItem = NSMenuItem(title: "World Clock", action: nil, keyEquivalent: "")
    var onStatusChange: (() -> Void)?

    /// City name → IANA time-zone identifier. A fixed list rather than a
    /// search field: a menu can't host a good one, and these cover the zones
    /// people actually schedule across.
    static let cities: [(name: String, zone: String)] = [
        ("Honolulu", "Pacific/Honolulu"), ("Los Angeles", "America/Los_Angeles"),
        ("Denver", "America/Denver"), ("Chicago", "America/Chicago"),
        ("New York", "America/New_York"), ("São Paulo", "America/Sao_Paulo"),
        ("UTC", "UTC"), ("London", "Europe/London"), ("Paris", "Europe/Paris"),
        ("Berlin", "Europe/Berlin"), ("Cairo", "Africa/Cairo"), ("Dubai", "Asia/Dubai"),
        ("Mumbai", "Asia/Kolkata"), ("Bangkok", "Asia/Bangkok"),
        ("Singapore", "Asia/Singapore"), ("Hong Kong", "Asia/Hong_Kong"),
        ("Seoul", "Asia/Seoul"), ("Tokyo", "Asia/Tokyo"),
        ("Sydney", "Australia/Sydney"), ("Auckland", "Pacific/Auckland"),
    ]

    private static let chosenKey = "com.maxcandela.worldclock.cities"
    private static let defaultCities = ["New York", "London", "Tokyo"]

    private let submenu = NSMenu()
    private var clockItems: [(item: NSMenuItem, name: String, zone: TimeZone)] = []

    private var chosen: [String] {
        get { UserDefaults.standard.stringArray(forKey: Self.chosenKey) ?? Self.defaultCities }
        set { UserDefaults.standard.set(newValue, forKey: Self.chosenKey) }
    }

    init() {
        menuItem.submenu = submenu
        menuItem.symbol("globe")
        rebuild()
    }

    func menuWillOpen() { rebuild() }
    func tick() { updateTimes() }

    /// Pure, unit-tested. "Tokyo — 9:41 PM", with "tomorrow"/"yesterday" when
    /// the city is on a different calendar day from `local` — the detail
    /// that actually causes missed meetings.
    static func row(city: String, zone: TimeZone, now: Date,
                    local: TimeZone = .current, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = zone
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        var text = "\(city) — \(formatter.string(from: now))"

        var there = Calendar(identifier: .gregorian)
        there.timeZone = zone
        var here = Calendar(identifier: .gregorian)
        here.timeZone = local
        let thereDay = there.dateComponents([.year, .month, .day], from: now)
        let hereDay = here.dateComponents([.year, .month, .day], from: now)
        // Compare the two wall-calendar dates as if they were in one zone.
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        if let a = utc.date(from: thereDay), let b = utc.date(from: hereDay) {
            let days = utc.dateComponents([.day], from: b, to: a).day ?? 0
            if days > 0 { text += ", tomorrow" }
            if days < 0 { text += ", yesterday" }
        }
        return text
    }

    private func rebuild() {
        submenu.removeAllItems()
        clockItems = []
        let names = chosen
        for city in Self.cities where names.contains(city.name) {
            guard let zone = TimeZone(identifier: city.zone) else { continue }
            let item = NSMenuItem(title: "", action: #selector(copyRow(_:)), keyEquivalent: "")
            item.target = self
            item.toolTip = "Click to copy"
            submenu.addItem(item.symbol("clock"))
            clockItems.append((item, city.name, zone))
        }
        if clockItems.isEmpty {
            let empty = NSMenuItem(title: "No cities chosen", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
        }

        submenu.addItem(.separator())
        let citiesItem = NSMenuItem(title: "Cities", action: nil, keyEquivalent: "")
        let citiesMenu = NSMenu()
        for city in Self.cities {
            let item = NSMenuItem(title: city.name, action: #selector(toggleCity(_:)), keyEquivalent: "")
            item.target = self
            item.state = names.contains(city.name) ? .on : .off
            citiesMenu.addItem(item)
        }
        citiesItem.submenu = citiesMenu
        submenu.addItem(citiesItem.symbol("list.bullet"))
        updateTimes()
    }

    private func updateTimes() {
        let now = Date()
        for clock in clockItems {
            let title = Self.row(city: clock.name, zone: clock.zone, now: now)
            if clock.item.title != title { clock.item.title = title }
        }
    }

    @objc private func toggleCity(_ sender: NSMenuItem) {
        var names = chosen
        if let index = names.firstIndex(of: sender.title) {
            names.remove(at: index)
        } else {
            names.append(sender.title)
        }
        chosen = names
    }

    @objc private func copyRow(_ sender: NSMenuItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(sender.title, forType: .string)
    }
}
