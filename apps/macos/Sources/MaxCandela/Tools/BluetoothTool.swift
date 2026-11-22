import AppKit
import CoreBluetooth
import IOBluetooth

/// What a paired device is, for its icon. Pure, unit-tested.
enum BluetoothDeviceKind: CaseIterable {
    case airpods, headphones, speaker, keyboard, mouse, trackpad, gameController, phone, other

    /// SF Symbols that exist on every macOS this app supports (12 or older).
    var symbol: String {
        switch self {
        case .airpods: return "airpods"
        case .headphones: return "headphones"
        case .speaker: return "hifispeaker"
        case .keyboard: return "keyboard"
        case .mouse: return "computermouse"
        case .trackpad: return "rectangle.and.hand.point.up.left"
        case .gameController: return "gamecontroller"
        case .phone: return "iphone"
        case .other: return "dot.radiowaves.left.and.right"
        }
    }

    /// From the device's Bluetooth Class of Device (the 24-bit value in the
    /// Bluetooth SIG's Assigned Numbers: major class in bits 12–8, minor in
    /// bits 7–2), falling back to the name. LE-only devices have no class at
    /// all (0), so for them the name is all there is.
    static func classify(classOfDevice: UInt32, name: String) -> BluetoothDeviceKind {
        let lower = name.lowercased()
        // AirPods report "headphones"; the name buys them their own icon.
        if lower.contains("airpods") { return .airpods }
        let major = (classOfDevice >> 8) & 0x1F
        let minor = (classOfDevice >> 2) & 0x3F
        switch major {
        case 0x02:                                    // Phone
            return .phone
        case 0x04:                                    // Audio/Video
            switch minor {
            case 0x01, 0x02, 0x06: return .headphones // headset, hands-free, headphones
            case 0x05, 0x07, 0x08, 0x0A, 0x0F: return .speaker // loudspeaker, portable, car, hi-fi, display+speaker
            default: break
            }
        case 0x05:                                    // Peripheral
            let kind = minor & 0x30, subtype = minor & 0x0F
            if subtype == 0x01 || subtype == 0x02 { return .gameController } // joystick, gamepad
            if kind == 0x20 {                         // pointing device
                return subtype == 0x05 || lower.contains("trackpad") ? .trackpad : .mouse
            }
            if kind == 0x10 || kind == 0x30 { return .keyboard } // keyboard, keyboard + pointing
        case 0x08 where minor == 0x04:                // Toy ▸ Controller
            return .gameController
        default:
            break
        }
        return fromName(lower)
    }

    private static func fromName(_ lower: String) -> BluetoothDeviceKind {
        let rules: [(BluetoothDeviceKind, [String])] = [
            (.trackpad, ["trackpad"]),
            (.mouse, ["mouse"]),
            (.keyboard, ["keyboard"]),
            (.gameController, ["controller", "gamepad", "dualsense", "dualshock", "joy-con"]),
            (.headphones, ["headphone", "headset", "buds", "beats"]),
            (.speaker, ["speaker", "soundlink", "boom"]),
            (.phone, ["iphone"]),
        ]
        return rules.first { $0.1.contains(where: lower.contains) }?.0 ?? .other
    }
}

/// One device's connection as the menu shows it. Pure, unit-tested.
enum BluetoothLink: Equatable {
    case connected, disconnected, connecting, disconnecting, connectFailed, disconnectFailed

    /// `pending`: an operation in flight (true = connecting). `failed`: the
    /// last operation failed (true = it was a connect). A failure only shows
    /// while the device is still in the state the user tried to leave.
    init(isConnected: Bool, pending: Bool?, failed: Bool?) {
        if let pending {
            self = pending ? .connecting : .disconnecting
        } else if let failed, failed != isConnected {
            self = failed ? .connectFailed : .disconnectFailed
        } else {
            self = isConnected ? .connected : .disconnected
        }
    }

    /// A check mark means "connected right now".
    var isChecked: Bool {
        switch self {
        case .connected, .disconnecting, .disconnectFailed: return true
        case .disconnected, .connecting, .connectFailed: return false
        }
    }

    /// What clicking the row does: true = connect, false = disconnect, nil =
    /// nothing (an operation is already running).
    var clickConnects: Bool? {
        switch self {
        case .connecting, .disconnecting: return nil
        default: return !isChecked
        }
    }

    var note: String? {
        switch self {
        case .connecting: return "Connecting…"
        case .disconnecting: return "Disconnecting…"
        case .connectFailed: return "Couldn’t connect"
        case .disconnectFailed: return "Couldn’t disconnect"
        case .connected, .disconnected: return nil
        }
    }

    /// `openConnection` reports "already exists" as an error, and the
    /// connection state is the ground truth either way, so an operation
    /// counts as done if it said so or the device ended up where asked.
    static func succeeded(result: IOReturn, wantConnected: Bool, isConnectedAfter: Bool) -> Bool {
        result == kIOReturnSuccess || isConnectedAfter == wantConnected
    }
}

/// What the background queue reads from IOBluetooth: plain values, so the
/// main thread never has to call into a device that may be mid-connect.
struct BluetoothDeviceSnapshot: Equatable {
    let address: String
    let name: String
    let classOfDevice: UInt32
    let isConnected: Bool
}

/// One row of the submenu. Pure, unit-tested.
struct BluetoothRow: Equatable {
    let address: String
    let name: String
    let kind: BluetoothDeviceKind
    let link: BluetoothLink
    let battery: Int?

    /// The dimmed text after the name: what is happening, or else the
    /// battery level of a connected device that reports one.
    var detail: String? {
        if let note = link.note { return note }
        guard link == .connected, let battery else { return nil }
        return "\(battery)%"
    }

    static func make(_ device: BluetoothDeviceSnapshot, pending: Bool?, failed: Bool?,
                     batteries: [String: Int]) -> BluetoothRow {
        BluetoothRow(address: device.address, name: device.name,
                     kind: .classify(classOfDevice: device.classOfDevice, name: device.name),
                     link: BluetoothLink(isConnected: device.isConnected, pending: pending, failed: failed),
                     battery: device.isConnected ? batteries[device.name] : nil)
    }

    /// Connected devices first, then by name the way Finder sorts.
    static func sorted(_ rows: [BluetoothRow]) -> [BluetoothRow] {
        rows.sorted { a, b in
            if a.link.isChecked != b.link.isChecked { return a.link.isChecked }
            let order = a.name.localizedStandardCompare(b.name)
            return order == .orderedSame ? a.address < b.address : order == .orderedAscending
        }
    }
}

/// Whether the device list can be shown, and if not, why. Pure, unit-tested.
enum BluetoothAvailability: Equatable {
    case installedAppOnly, needsPermission, denied, restricted, unsupported, off, starting, ready

    /// `radio` is the CoreBluetooth central's state, nil before it exists.
    static func resolve(canAsk: Bool, authorization: CBManagerAuthorization,
                        radio: CBManagerState?) -> BluetoothAvailability {
        guard canAsk else { return .installedAppOnly }
        switch authorization {
        case .notDetermined: return .needsPermission
        case .restricted: return .restricted
        case .allowedAlways: break
        case .denied: return .denied
        @unknown default: return .denied
        }
        switch radio {
        case .poweredOn: return .ready
        case .poweredOff: return .off
        case .unsupported: return .unsupported
        case .unauthorized: return .denied
        default: return .starting
        }
    }

    /// The explanatory row, when the list can't be shown.
    var message: String? {
        switch self {
        case .installedAppOnly: return "Available in the installed app"
        case .needsPermission: return nil
        case .denied: return "Bluetooth access is off for MaxCandela"
        case .restricted: return "Bluetooth is restricted on this Mac"
        case .unsupported: return "This Mac has no Bluetooth"
        case .off: return "Bluetooth is off"
        case .starting: return "Checking Bluetooth…"
        case .ready: return nil
        }
    }

    /// Where the user fixes it. Apple documents no URL for the Bluetooth or
    /// Privacy panes of System Settings, so the row opens System Settings
    /// itself and this hint (the row's tooltip) names the pane.
    var settingsHint: String? {
        switch self {
        case .denied: return "Privacy & Security ▸ Bluetooth ▸ MaxCandela"
        case .off: return "Turn Bluetooth on in Control Center, or in System Settings ▸ Bluetooth"
        default: return nil
        }
    }
}

/// Bluetooth (Pro): the Mac's paired devices, one click to connect or
/// disconnect — AirPods, headphones, speakers, keyboards, mice, trackpads,
/// game controllers — with the battery level of those that report it the
/// standard way (see `BluetoothCentral` for which ones, and why not AirPods).
///
/// IOBluetooth for the list and the connections, CoreBluetooth for the
/// permission, the radio state and the battery. Unlike the other tools this
/// one needs a sandbox entitlement — `com.apple.security.device.bluetooth` —
/// and `NSBluetoothAlwaysUsageDescription` in Info.plist; the system asks for
/// Bluetooth access the first time the user clicks "Allow Bluetooth Access…",
/// never at launch. A bare `swift run` binary has no Info.plist, and a process
/// that asks for a privacy permission without the usage string is killed, so
/// the tool checks for the key and stays inert there (as Next Meeting does).
///
/// Threading: `openConnection` / `closeConnection` are synchronous and can
/// take seconds, so every call into an `IOBluetoothDevice` — listing included
/// — runs on one serial background queue and comes back as plain values
/// (`BluetoothDeviceSnapshot`). The main thread only renders and registers
/// for IOBluetooth's connect/disconnect notifications (which arrive on the
/// thread that registered).
///
/// ⚠️ Not exercised at runtime during development: no Bluetooth permission for
/// the dev binary, and nothing may touch this Mac's devices. The labelling,
/// sorting and state logic are unit-tested; the IOBluetooth calls are not.
final class BluetoothTool: NSObject, MenuTool, NSMenuDelegate {
    let menuItem = NSMenuItem(title: "Bluetooth", action: nil, keyEquivalent: "")
    var onStatusChange: (() -> Void)?
    var isPro: Bool { true }

    private let submenu = NSMenu()
    private let central = BluetoothCentral()
    private let queue = DispatchQueue(label: "com.maxcandela.bluetooth", qos: .userInitiated)

    /// The last list read on `queue`; nil until the first read lands.
    private var snapshot: [BluetoothDeviceSnapshot]?
    private var snapshotQueued = false
    private var snapshotStale = false

    /// address → true while connecting, false while disconnecting.
    private var pending: [String: Bool] = [:]
    /// address → the operation that failed (true = connect) and when.
    private var failures: [String: (connect: Bool, at: Date)] = [:]
    private static let failureNoteSeconds: TimeInterval = 60

    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotifications: [String: IOBluetoothUserNotification] = [:]

    private var submenuIsOpen = false
    /// Addresses of the device rows on screen, in order; nil while the
    /// submenu shows a message instead. Lets an update on an *open* menu
    /// retitle rows in place rather than rebuild them under the pointer.
    private var renderedAddresses: [String]?
    private var deviceItems: [NSMenuItem] = []

    private static var canAsk: Bool {
        Bundle.main.object(forInfoDictionaryKey: "NSBluetoothAlwaysUsageDescription") != nil
    }

    override init() {
        super.init()
        submenu.delegate = self
        menuItem.submenu = submenu
        menuItem.symbol("dot.radiowaves.left.and.right")
        central.onStateChange = { [weak self] in self?.radioChanged() }
        central.onReadingsChange = { [weak self] in self?.renderIfOpen() }
        ProGate.shared.observe { [weak self] allowed in
            if !allowed { self?.stopListening() }
        }
        // Nothing here may touch Bluetooth: this runs at launch for everyone.
        render()
    }

    /// The main menu is opening: refresh in the background so the submenu
    /// is current by the time the pointer reaches it. Only once access has
    /// been granted — before that, nothing may trigger the prompt.
    func menuWillOpen() {
        guard isAuthorized else { return }
        startListening()
        requestSnapshot()
        central.refreshBatteries()
    }

    func shutdown() { stopListening() }

    private var isAuthorized: Bool {
        Self.canAsk && ProGate.shared.isAllowed && CBManager.authorization == .allowedAlways
    }

    // MARK: - NSMenuDelegate (the Bluetooth submenu)

    func menuNeedsUpdate(_ menu: NSMenu) {
        if isAuthorized {
            startListening()
            requestSnapshot()
            central.refreshBatteries()
        }
        render()
    }

    func menuWillOpen(_ menu: NSMenu) {
        submenuIsOpen = true
    }

    /// No row has a key equivalent. Saying so up front stops AppKit calling
    /// `menuNeedsUpdate` (and so reading devices) just to search for one.
    func menuHasKeyEquivalent(_ menu: NSMenu, for event: NSEvent,
                              target: AutoreleasingUnsafeMutablePointer<AnyObject?>,
                              action: UnsafeMutablePointer<Selector?>) -> Bool {
        false
    }

    func menuDidClose(_ menu: NSMenu) {
        submenuIsOpen = false
    }

    // MARK: - Listening

    /// Idempotent. Creating the central here never prompts: callers check
    /// that access is already granted.
    private func startListening() {
        central.start()
        guard connectNotification == nil else { return }
        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self, selector: #selector(deviceConnected(_:device:)))
    }

    private func stopListening() {
        connectNotification?.unregister()
        connectNotification = nil
        disconnectNotifications.values.forEach { $0.unregister() }
        disconnectNotifications.removeAll()
        central.stop()
        snapshot = nil
    }

    @objc private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        if let address = device.addressString { watchDisconnect(of: address) }
        if submenuIsOpen { requestSnapshot() }
    }

    @objc private func deviceDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        notification.unregister()
        if let address = device.addressString { disconnectNotifications[address] = nil }
        if submenuIsOpen { requestSnapshot() }
    }

    private func watchDisconnect(of address: String) {
        guard connectNotification != nil, disconnectNotifications[address] == nil,
              let device = IOBluetoothDevice(addressString: address),
              let notification = device.register(forDisconnectNotification: self,
                                                 selector: #selector(deviceDisconnected(_:device:))) else { return }
        disconnectNotifications[address] = notification
    }

    private func radioChanged() {
        // Access may just have been granted from the prompt.
        if isAuthorized {
            startListening()
            requestSnapshot()
            central.refreshBatteries()
        }
        renderIfOpen()
    }

    // MARK: - Reading the list (background)

    /// Coalesced: a burst of notifications costs one read, plus one more if
    /// something changed while that read was running.
    private func requestSnapshot() {
        guard !snapshotQueued else {
            snapshotStale = true
            return
        }
        snapshotQueued = true
        queue.async { [weak self] in
            let devices = Self.readDevices()
            DispatchQueue.main.async { self?.snapshotArrived(devices) }
        }
    }

    private func snapshotArrived(_ devices: [BluetoothDeviceSnapshot]) {
        snapshotQueued = false
        store(devices)
        renderIfOpen()
        if snapshotStale {
            snapshotStale = false
            requestSnapshot()
        }
    }

    private func store(_ devices: [BluetoothDeviceSnapshot]) {
        guard connectNotification != nil else { return }   // stopped meanwhile
        snapshot = devices
        // Watch each connected device for its disconnect; forget watches on
        // devices that went away while nobody was listening.
        let connected = Set(devices.filter(\.isConnected).map(\.address))
        for (address, notification) in disconnectNotifications where !connected.contains(address) {
            notification.unregister()
            disconnectNotifications[address] = nil
        }
        connected.forEach(watchDisconnect(of:))
    }

    /// Runs on `queue` only.
    private static func readDevices() -> [BluetoothDeviceSnapshot] {
        let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        return paired.compactMap { device in
            guard let address = device.addressString, !address.isEmpty else { return nil }
            let name = device.name.flatMap { $0.isEmpty ? nil : $0 } ?? address
            return BluetoothDeviceSnapshot(address: address, name: name,
                                           classOfDevice: device.classOfDevice,
                                           isConnected: device.isConnected())
        }
    }

    // MARK: - Connecting (background)

    @objc private func toggle(_ sender: NSMenuItem) {
        guard let address = sender.representedObject as? String, pending[address] == nil,
              let device = snapshot?.first(where: { $0.address == address }) else { return }
        let connect = !device.isConnected
        pending[address] = connect
        failures[address] = nil
        renderIfOpen()
        queue.async { [weak self] in
            var result = kIOReturnNoDevice
            var connectedAfter = !connect
            if let device = IOBluetoothDevice(addressString: address) {
                result = connect ? device.openConnection() : device.closeConnection()
                connectedAfter = device.isConnected()
            }
            let devices = Self.readDevices()
            DispatchQueue.main.async {
                self?.finish(address: address, connect: connect, result: result,
                             connectedAfter: connectedAfter, devices: devices)
            }
        }
    }

    private func finish(address: String, connect: Bool, result: IOReturn,
                        connectedAfter: Bool, devices: [BluetoothDeviceSnapshot]) {
        pending[address] = nil
        if !BluetoothLink.succeeded(result: result, wantConnected: connect, isConnectedAfter: connectedAfter) {
            failures[address] = (connect, Date())
            NSSound.beep()
            NSLog("MaxCandela: Bluetooth %@ failed: 0x%08x", connect ? "connect" : "disconnect", UInt32(bitPattern: result))
        }
        store(devices)
        renderIfOpen()
    }

    // MARK: - Rendering

    private func renderIfOpen() {
        if submenuIsOpen { render() }
    }

    private func render() {
        guard Self.canAsk else {
            return showMessage(BluetoothAvailability.installedAppOnly.message, availability: .installedAppOnly)
        }
        // Locked, the whole item is hidden (MenuBarController shows the
        // "— Pro" row instead); don't read anything for it.
        guard ProGate.shared.isAllowed else {
            return showMessage(BluetoothAvailability.starting.message, availability: .starting)
        }
        let availability = BluetoothAvailability.resolve(canAsk: true, authorization: CBManager.authorization,
                                                         radio: central.state)
        guard availability == .ready else {
            return showMessage(availability.message, availability: availability)
        }
        guard let snapshot else { return showMessage(BluetoothAvailability.starting.message, availability: .starting) }
        guard !snapshot.isEmpty else { return showMessage("No paired devices", availability: .ready) }

        let now = Date()
        failures = failures.filter { now.timeIntervalSince($0.value.at) < Self.failureNoteSeconds }
        let batteries = BluetoothCentral.levelsByName(Array(central.readings.values))
        let rows = BluetoothRow.sorted(snapshot.map {
            BluetoothRow.make($0, pending: pending[$0.address], failed: failures[$0.address]?.connect,
                              batteries: batteries)
        })
        showDevices(rows)
    }

    private func showDevices(_ rows: [BluetoothRow]) {
        let addresses = rows.map(\.address)
        if renderedAddresses != addresses {
            submenu.removeAllItems()
            deviceItems = rows.map { _ in
                let item = NSMenuItem(title: "", action: #selector(toggle(_:)), keyEquivalent: "")
                item.target = self
                submenu.addItem(item)
                return item
            }
            renderedAddresses = addresses
        }
        for (item, row) in zip(deviceItems, rows) {
            item.representedObject = row.address
            item.state = row.link.isChecked ? .on : .off
            item.isEnabled = row.link.clickConnects != nil
            item.symbol(row.kind.symbol)
            setTitle(item, name: row.name, detail: row.detail)
        }
    }

    private func showMessage(_ message: String?, availability: BluetoothAvailability) {
        submenu.removeAllItems()
        renderedAddresses = nil
        deviceItems = []
        if let message {
            let item = NSMenuItem(title: message, action: nil, keyEquivalent: "")
            item.isEnabled = false
            submenu.addItem(item)
        }
        switch availability {
        case .needsPermission:
            let item = NSMenuItem(title: "Allow Bluetooth Access…", action: #selector(requestAccess), keyEquivalent: "")
            item.target = self
            submenu.addItem(item.symbol("lock.open"))
        case .denied, .off:
            let item = NSMenuItem(title: "Open System Settings…", action: #selector(openSettings), keyEquivalent: "")
            item.target = self
            item.toolTip = availability.settingsHint
            submenu.addItem(item.symbol("gearshape"))
        default:
            break
        }
    }

    /// "AirPods Pro   85%", the detail in secondary colour (as the boost row
    /// does). Plain `title` is kept in sync for accessibility.
    private func setTitle(_ item: NSMenuItem, name: String, detail: String?) {
        guard let detail else {
            item.attributedTitle = nil
            item.title = name
            return
        }
        item.title = "\(name) — \(detail)"
        let font = NSFont.menuFont(ofSize: 0)
        let title = NSMutableAttributedString(string: name, attributes: [.font: font])
        title.append(NSAttributedString(
            string: "   \(detail)",
            attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor]))
        item.attributedTitle = title
    }

    // MARK: - Actions

    @objc private func requestAccess() {
        NSApp.activate(ignoringOtherApps: true)
        // Creating the central is what shows the prompt; the answer comes
        // back as a state change (`radioChanged`).
        central.start()
    }

    @objc private func openSettings() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.systempreferences") else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
