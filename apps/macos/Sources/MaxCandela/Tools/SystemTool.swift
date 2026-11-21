import AppKit
import IOKit
import IOKit.ps

/// Raw readings, split from the menu so the arithmetic is unit-testable.
/// Everything here is a public Mach / IOKit / Foundation read that works
/// inside the sandbox — no SMC, no private frameworks, so no fan speeds and
/// no per-core temperatures (those need the privileged helper the App Store
/// forbids; see "Thermal handling" in CLAUDE.md).
enum SystemStats {
    struct CPUTicks: Equatable {
        var busy: UInt64
        var idle: UInt64
    }

    /// Cumulative CPU ticks since boot, all cores together.
    static func cpuTicks() -> CPUTicks? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        // cpu_ticks: (user, system, idle, nice)
        let ticks = info.cpu_ticks
        return CPUTicks(busy: UInt64(ticks.0) + UInt64(ticks.1) + UInt64(ticks.3), idle: UInt64(ticks.2))
    }

    /// Pure, unit-tested. Share of time spent busy between two samples, 0…1,
    /// or nil when no time passed (or the counters wrapped).
    static func cpuUsage(from previous: CPUTicks, to current: CPUTicks) -> Double? {
        guard current.busy >= previous.busy, current.idle >= previous.idle else { return nil }
        let busy = current.busy - previous.busy
        let total = busy + (current.idle - previous.idle)
        return total > 0 ? Double(busy) / Double(total) : nil
    }

    /// Memory in use the way Activity Monitor counts "Memory Used": app
    /// (active) + wired + compressed.
    static func memoryUsed() -> UInt64? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let pages = UInt64(stats.active_count) + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)
        return pages * UInt64(vm_kernel_page_size)
    }

    static func disk() -> (free: Int64, total: Int64)? {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey,
                                                               .volumeTotalCapacityKey]),
              let free = values.volumeAvailableCapacityForImportantUsage,
              let total = values.volumeTotalCapacity else { return nil }
        return (free, Int64(total))
    }

    struct Battery {
        var percent: Int
        var isCharging: Bool
        var cycleCount: Int?
        /// Full-charge capacity as a share of the design capacity, 0…1+.
        var health: Double?
    }

    /// nil on a Mac with no battery.
    static func battery() -> Battery? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                  info[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = info[kIOPSCurrentCapacityKey] as? Int,
                  let max = info[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            var battery = Battery(percent: Int((Double(current) / Double(max) * 100).rounded()),
                                  isCharging: info[kIOPSIsChargingKey] as? Bool ?? false)
            // Same registry entry ChassisTemperature reads, verified readable
            // under the shipping sandbox entitlements.
            let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
            if service != 0 {
                defer { IOObjectRelease(service) }
                func number(_ key: String) -> Double? {
                    (IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                        .takeRetainedValue() as? NSNumber)?.doubleValue
                }
                battery.cycleCount = number("CycleCount").map(Int.init)
                battery.health = health(rawMaxCapacity: number("AppleRawMaxCapacity"),
                                        designCapacity: number("DesignCapacity"))
            }
            return battery
        }
        return nil
    }

    /// Pure, unit-tested. Discards readings that can't be a real ratio.
    static func health(rawMaxCapacity: Double?, designCapacity: Double?) -> Double? {
        guard let rawMaxCapacity, let designCapacity, designCapacity > 0, rawMaxCapacity > 0 else { return nil }
        let ratio = rawMaxCapacity / designCapacity
        return (0.1...1.5).contains(ratio) ? ratio : nil
    }

    static func bootDate() -> Date? {
        var boot = timeval()
        var size = MemoryLayout<timeval>.stride
        guard sysctlbyname("kern.boottime", &boot, &size, nil, 0) == 0, boot.tv_sec > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(boot.tv_sec))
    }

    /// Pure, unit-tested. "3 d 4 h", "5 h 12 min", "8 min".
    static func uptimeText(seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds / 60))
        let (d, h, m) = (minutes / 1440, (minutes % 1440) / 60, minutes % 60)
        if d > 0 { return "\(d) d \(h) h" }
        if h > 0 { return "\(h) h \(m) min" }
        return "\(m) min"
    }

    /// The Mac's address on the local network (first active IPv4 that isn't
    /// loopback or link-local). Read locally — nothing is sent anywhere.
    static func localIPAddress() -> String? {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return nil }
        defer { freeifaddrs(list) }
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            guard let address = interface.ifa_addr, address.pointee.sa_family == UInt8(AF_INET),
                  interface.ifa_flags & UInt32(IFF_UP) != 0,
                  interface.ifa_flags & UInt32(IFF_LOOPBACK) == 0 else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count),
                              nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let text = String(cString: host)
            if !text.hasPrefix("169.254.") { return text }
        }
        return nil
    }
}

/// A figure the user can pin to the menu bar, next to the ☀️.
enum SystemPin: String, CaseIterable {
    case cpu, memory, disk, battery

    var title: String {
        switch self {
        case .cpu: return "CPU"
        case .memory: return "Memory"
        case .disk: return "Free Disk Space"
        case .battery: return "Battery"
        }
    }

    /// Pure, unit-tested. The pinned figures in a fixed order, short enough
    /// for the menu bar: "CPU 12%  RAM 61%  SSD 212 GB  BAT 84%". A figure
    /// that can't be read (no battery on a desktop) is left out, not shown
    /// as a dash. Percentages are padded with a figure space so the text
    /// keeps its width as 9% becomes 10% and the menu bar doesn't shuffle.
    static func statusText(pins: Set<SystemPin>, cpu: Double?, memory: Double?,
                           diskFreeBytes: Int64?, battery: Int?) -> String? {
        func percent(_ fraction: Double) -> String {
            let value = Int((max(0, min(1, fraction)) * 100).rounded())
            return (value < 10 ? "\u{2007}" : "") + "\(value)%"
        }
        var parts: [String] = []
        if pins.contains(.cpu), let cpu { parts.append("CPU \(percent(cpu))") }
        if pins.contains(.memory), let memory { parts.append("RAM \(percent(memory))") }
        if pins.contains(.disk), let diskFreeBytes {
            parts.append("SSD \(Int((Double(diskFreeBytes) / 1_000_000_000).rounded())) GB")
        }
        if pins.contains(.battery), let battery { parts.append("BAT \(percent(Double(battery) / 100))") }
        return parts.isEmpty ? nil : parts.joined(separator: "  ")
    }
}

/// System: a live read-out of CPU, memory, disk, battery, uptime and the
/// local IP address. Clicking a row copies its figure; "Show in Menu Bar"
/// pins the ones you choose next to the status icon.
final class SystemTool: MenuTool {
    let menuItem = NSMenuItem(title: "System", action: nil, keyEquivalent: "")
    var onStatusChange: (() -> Void)?

    // MARK: Pinned figures

    private static let pinsKey = "com.maxcandela.system.pins"
    private let pinsMenu = NSMenu()
    private var pinTimer: Timer?
    private var pinTicks: SystemStats.CPUTicks?
    private var pinnedCPU: Double?
    private(set) var statusText: String?

    private var pins: Set<SystemPin> {
        get { Set((UserDefaults.standard.stringArray(forKey: Self.pinsKey) ?? []).compactMap(SystemPin.init)) }
        set { UserDefaults.standard.set(newValue.map(\.rawValue).sorted(), forKey: Self.pinsKey) }
    }

    /// Runs only while something is pinned. Every 2 s: often enough to feel
    /// live, slow enough that the sampling itself doesn't show up in the CPU
    /// figure it reports. Its own tick state, separate from the open-menu
    /// read-out, so the two sampling intervals don't shorten each other.
    private func restartPinTimer() {
        pinTimer?.invalidate()
        pinTimer = nil
        pinnedCPU = nil
        guard !pins.isEmpty else {
            statusText = nil
            onStatusChange?()
            return
        }
        pinTicks = SystemStats.cpuTicks()
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            self?.updatePinned()
        }
        timer.tolerance = 0.3
        RunLoop.main.add(timer, forMode: .common)
        pinTimer = timer
        updatePinned()
    }

    private func updatePinned() {
        let current = pins
        if current.contains(.cpu), let ticks = SystemStats.cpuTicks() {
            if let previous = pinTicks, let usage = SystemStats.cpuUsage(from: previous, to: ticks) {
                pinnedCPU = usage
            }
            pinTicks = ticks
        }
        let total = Double(ProcessInfo.processInfo.physicalMemory)
        let memory = current.contains(.memory) ? SystemStats.memoryUsed().map { Double($0) / total } : nil
        let disk = current.contains(.disk) ? SystemStats.disk()?.free : nil
        let battery = current.contains(.battery) ? SystemStats.battery()?.percent : nil
        let text = SystemPin.statusText(pins: current, cpu: pinnedCPU, memory: memory,
                                        diskFreeBytes: disk, battery: battery)
        guard text != statusText else { return }
        statusText = text
        onStatusChange?()
    }

    @objc private func togglePin(_ sender: NSMenuItem) {
        guard let pin = sender.representedObject as? String, let value = SystemPin(rawValue: pin) else { return }
        var current = pins
        if current.contains(value) { current.remove(value) } else { current.insert(value) }
        pins = current
        restartPinTimer()
    }

    private func updatePinsMenu() {
        let current = pins
        for item in pinsMenu.items {
            guard let raw = item.representedObject as? String, let pin = SystemPin(rawValue: raw) else { continue }
            item.state = current.contains(pin) ? .on : .off
        }
    }

    func shutdown() { pinTimer?.invalidate() }

    private let submenu = NSMenu()
    private let cpuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let memoryItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let diskItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let batteryItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let batteryHealthItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let uptimeItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let ipItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    private var lastTicks: SystemStats.CPUTicks?
    private var lastSampleAt = Date.distantPast
    private var cpuText = "…"

    private static let bytes: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter
    }()

    private static let diskBytes: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    init() {
        let rows: [(NSMenuItem, String)] = [
            (cpuItem, "cpu"), (memoryItem, "memorychip"), (diskItem, "internaldrive"),
            (batteryItem, "battery.75"), (batteryHealthItem, "heart"), (uptimeItem, "clock"),
        ]
        // Real rows, not disabled ones: AppKit draws a disabled row grey, which
        // made the whole read-out look unavailable. Each copies itself.
        for (item, symbol) in rows + [(ipItem, "network")] {
            item.target = self
            item.action = #selector(copyRow(_:))
            item.toolTip = "Click to copy"
            item.symbol(symbol)
        }
        rows.forEach { submenu.addItem($0.0) }
        submenu.addItem(.separator())
        submenu.addItem(ipItem)

        submenu.addItem(.separator())
        for pin in SystemPin.allCases {
            let item = NSMenuItem(title: pin.title, action: #selector(togglePin(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = pin.rawValue
            pinsMenu.addItem(item)
        }
        let pinsItem = NSMenuItem(title: "Show in Menu Bar", action: nil, keyEquivalent: "")
        pinsItem.submenu = pinsMenu
        submenu.addItem(pinsItem.symbol("pin"))
        menuItem.submenu = submenu
        restartPinTimer()
        menuItem.symbol("cpu")
    }

    func menuWillOpen() {
        // Prime the CPU sample so the first figure covers the time until the
        // next tick rather than everything since boot.
        lastTicks = SystemStats.cpuTicks()
        lastSampleAt = Date()
        cpuText = "…"
        updatePinsMenu()
        update()
    }

    func tick() {
        // The menu ticker runs at 5 Hz; a CPU figure over 0.2 s is noise.
        guard Date().timeIntervalSince(lastSampleAt) >= 1 else { return }
        if let current = SystemStats.cpuTicks() {
            if let previous = lastTicks, let usage = SystemStats.cpuUsage(from: previous, to: current) {
                cpuText = String(format: "%.0f%%", usage * 100)
            }
            lastTicks = current
        }
        lastSampleAt = Date()
        update()
    }

    private func update() {
        cpuItem.title = "CPU — \(cpuText)"

        let total = ProcessInfo.processInfo.physicalMemory
        if let used = SystemStats.memoryUsed() {
            memoryItem.title = "Memory — \(Self.bytes.string(fromByteCount: Int64(used))) of \(Self.bytes.string(fromByteCount: Int64(total)))"
        } else {
            memoryItem.title = "Memory — \(Self.bytes.string(fromByteCount: Int64(total)))"
        }

        if let disk = SystemStats.disk() {
            diskItem.title = "Disk — \(Self.diskBytes.string(fromByteCount: disk.free)) free of \(Self.diskBytes.string(fromByteCount: disk.total))"
            diskItem.isHidden = false
        } else {
            diskItem.isHidden = true
        }

        if let battery = SystemStats.battery() {
            batteryItem.title = "Battery — \(battery.percent)%\(battery.isCharging ? ", charging" : "")"
            batteryItem.isHidden = false
            var parts: [String] = []
            if let health = battery.health { parts.append(String(format: "%.0f%% health", health * 100)) }
            if let cycles = battery.cycleCount { parts.append("\(cycles) cycles") }
            batteryHealthItem.title = "Battery — " + parts.joined(separator: ", ")
            batteryHealthItem.isHidden = parts.isEmpty
        } else {
            batteryItem.isHidden = true
            batteryHealthItem.isHidden = true
        }

        if let boot = SystemStats.bootDate() {
            uptimeItem.title = "Uptime — \(SystemStats.uptimeText(seconds: Date().timeIntervalSince(boot)))"
            uptimeItem.isHidden = false
        } else {
            uptimeItem.isHidden = true
        }

        if let ip = SystemStats.localIPAddress() {
            ipItem.title = "Local IP — \(ip)"
            ipItem.isHidden = false
        } else {
            ipItem.isHidden = true
        }
    }

    /// Copies the figure — the part after the dash — so "Local IP —
    /// 192.168.1.20" pastes as the address alone.
    @objc private func copyRow(_ sender: NSMenuItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Self.value(ofRow: sender.title), forType: .string)
    }

    /// Pure, unit-tested.
    static func value(ofRow title: String) -> String {
        title.components(separatedBy: " — ").dropFirst().joined(separator: " — ")
            .trimmingCharacters(in: .whitespaces)
    }
}
