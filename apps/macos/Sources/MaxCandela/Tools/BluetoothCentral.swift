import CoreBluetooth

/// The Bluetooth tool's one CoreBluetooth central. Three jobs, all public,
/// documented API:
///
///  - creating it is what shows the system's Bluetooth permission prompt
///    (only ever on the user's click — `BluetoothTool` creates it unprompted
///    only once access is already granted);
///  - its `state` is the radio's state (on / off / unauthorised / no
///    hardware), and `onStateChange` fires when that changes;
///  - it reads battery levels through the standard GATT **Battery Service**
///    (0x180F, Battery Level 0x2A19 — a single byte, 0–100 %) from Bluetooth
///    LE devices the *system* already has connected.
///
/// Battery: this is the only documented route on macOS. IOBluetooth has no
/// battery property (its one battery API, `IOBluetoothHandsFreeDevice`, is
/// the *phone's* charge, and only when the Mac itself holds a Hands-Free link
/// to the phone). IOKit power sources document only internal batteries and
/// UPSs. What macOS shows for AirPods and Magic accessories comes from
/// undocumented IORegistry keys and private power-source calls, so those
/// devices show no figure here — only devices that expose the GATT Battery
/// Service do. A reading is matched to a paired device by name, because
/// CoreBluetooth never reveals a device's address; a name shared by two
/// readings is dropped rather than guessed (`levelsByName`).
///
/// A read connects *this app* to the peripheral, reads one byte and cancels
/// that local connection again. Apple documents that cancelling a local
/// connection does not drop a link other clients (here: the system) hold.
///
/// ⚠️ Not exercised at runtime during development (no Bluetooth permission
/// for the dev binary, and nothing may touch this Mac's devices). The byte
/// parsing and name matching are unit-tested.
final class BluetoothCentral: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    struct Reading: Equatable {
        let name: String?
        let level: Int
    }

    static let batteryService = CBUUID(string: "180F")
    static let batteryLevel = CBUUID(string: "2A19")
    /// A read still running after this long is abandoned and retried.
    private static let readTimeout: TimeInterval = 10

    var onStateChange: (() -> Void)?
    var onReadingsChange: (() -> Void)?

    private var central: CBCentralManager?
    /// Peripherals mid-read. CoreBluetooth does not retain them for us.
    private var inFlight: [UUID: (peripheral: CBPeripheral, started: Date)] = [:]
    private(set) var readings: [UUID: Reading] = [:]

    /// nil until `start()`.
    var state: CBManagerState? { central?.state }

    /// Shows the permission prompt if the user has not answered it yet.
    func start() {
        guard central == nil else { return }
        // Delegate callbacks on the main queue, which AppKit keeps servicing
        // while a menu is open (it drains in the common run-loop modes).
        central = CBCentralManager(delegate: self, queue: .main,
                                   options: [CBCentralManagerOptionShowPowerAlertKey: false])
    }

    func stop() {
        guard let central else { return }
        inFlight.values.forEach { central.cancelPeripheralConnection($0.peripheral) }
        inFlight.removeAll()
        readings.removeAll()
        central.delegate = nil
        self.central = nil
    }

    /// Re-reads every connected Battery Service device. Readings arrive later
    /// through `onReadingsChange`. A no-op unless the radio is on.
    func refreshBatteries() {
        guard let central, central.state == .poweredOn else { return }
        let connected = central.retrieveConnectedPeripherals(withServices: [Self.batteryService])
        let ids = Set(connected.map(\.identifier))
        if readings.keys.contains(where: { !ids.contains($0) }) {
            readings = readings.filter { ids.contains($0.key) }
            onReadingsChange?()
        }
        let now = Date()
        for peripheral in connected {
            if let started = inFlight[peripheral.identifier]?.started,
               now.timeIntervalSince(started) < Self.readTimeout { continue }
            inFlight[peripheral.identifier] = (peripheral, now)
            peripheral.delegate = self
            central.connect(peripheral, options: nil)
        }
    }

    // MARK: - Pure, unit-tested

    /// The Battery Level characteristic is one unsigned byte, 0–100 %.
    /// Anything else is not a level.
    static func level(from data: Data?) -> Int? {
        guard let data, data.count >= 1 else { return nil }
        let value = Int(data[data.startIndex])
        return (0...100).contains(value) ? value : nil
    }

    /// Readings keyed by device name, for matching against the paired list.
    /// Unnamed readings and names that occur more than once are left out: a
    /// figure shown against the wrong device is worse than none.
    static func levelsByName(_ readings: [Reading]) -> [String: Int] {
        var levels: [String: Int] = [:]
        var duplicates: Set<String> = []
        for reading in readings {
            guard let name = reading.name, !name.isEmpty else { continue }
            if levels[name] != nil { duplicates.insert(name) }
            levels[name] = reading.level
        }
        duplicates.forEach { levels[$0] = nil }
        return levels
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            inFlight.removeAll()
            readings.removeAll()
        }
        onStateChange?()
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([Self.batteryService])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        inFlight[peripheral.identifier] = nil
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        inFlight[peripheral.identifier] = nil
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil,
              let service = peripheral.services?.first(where: { $0.uuid == Self.batteryService }) else {
            return finish(peripheral)
        }
        peripheral.discoverCharacteristics([Self.batteryLevel], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil,
              let characteristic = service.characteristics?.first(where: { $0.uuid == Self.batteryLevel }) else {
            return finish(peripheral)
        }
        peripheral.readValue(for: characteristic)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error == nil, let level = Self.level(from: characteristic.value) {
            let reading = Reading(name: peripheral.name, level: level)
            if readings[peripheral.identifier] != reading {
                readings[peripheral.identifier] = reading
                onReadingsChange?()
            }
        }
        finish(peripheral)
    }

    /// Done with this peripheral: let go of our local connection only.
    private func finish(_ peripheral: CBPeripheral) {
        inFlight[peripheral.identifier] = nil
        central?.cancelPeripheralConnection(peripheral)
    }
}
