import AppKit
import CoreBluetooth
import IOKit
import XCTest
@testable import MaxCandela

/// Pure-logic tests for the Bluetooth tool. Nothing here touches Bluetooth:
/// no tool, central or IOBluetooth device is created — only the labelling,
/// state, sorting and parsing functions the tool renders from.
final class BluetoothToolTests: XCTestCase {

    // MARK: - Device kind (Class of Device values as real devices report them)

    func testAudioClasses() {
        // AirPods report Audio ▸ Headphones; the name earns them their icon.
        XCTAssertEqual(BluetoothDeviceKind.classify(classOfDevice: 0x240418, name: "Daniel’s AirPods Pro"), .airpods)
        XCTAssertEqual(BluetoothDeviceKind.classify(classOfDevice: 0x240418, name: "WH-1000XM4"), .headphones)
        XCTAssertEqual(BluetoothDeviceKind.classify(classOfDevice: 0x240404, name: "Jabra Talk"), .headphones)   // headset
        XCTAssertEqual(BluetoothDeviceKind.classify(classOfDevice: 0x240414, name: "JBL Flip 5"), .speaker)      // loudspeaker
        XCTAssertEqual(BluetoothDeviceKind.classify(classOfDevice: 0x24041C, name: "Pill"), .speaker)            // portable
    }

    func testPeripheralClasses() {
        XCTAssertEqual(BluetoothDeviceKind.classify(classOfDevice: 0x002540, name: "Magic Keyboard"), .keyboard)
        XCTAssertEqual(BluetoothDeviceKind.classify(classOfDevice: 0x0025C0, name: "K400"), .keyboard)           // combo
        XCTAssertEqual(BluetoothDeviceKind.classify(classOfDevice: 0x002580, name: "Magic Mouse"), .mouse)
        // Pointing + digitizer tablet, or a pointing device that says so.
        XCTAssertEqual(BluetoothDeviceKind.classify(classOfDevice: 0x002594, name: "Touch"), .trackpad)
        XCTAssertEqual(BluetoothDeviceKind.classify(classOfDevice: 0x002580, name: "Magic Trackpad"), .trackpad)
        XCTAssertEqual(BluetoothDeviceKind.classify(classOfDevice: 0x002508, name: "DualSense Wireless Controller"), .gameController)
        XCTAssertEqual(BluetoothDeviceKind.classify(classOfDevice: 0x002504, name: "Stick"), .gameController)    // joystick
        XCTAssertEqual(BluetoothDeviceKind.classify(classOfDevice: 0x000810, name: "Toy"), .gameController)      // toy ▸ controller
    }

    func testPhoneAndOtherClasses() {
        XCTAssertEqual(BluetoothDeviceKind.classify(classOfDevice: 0x7A020C, name: "Daniel’s iPhone"), .phone)
        XCTAssertEqual(BluetoothDeviceKind.classify(classOfDevice: 0x3C010C, name: "MacBook Pro"), .other)       // computer
    }

    func testLowEnergyDevicesFallBackToTheName() {
        // LE-only devices carry no Class of Device at all.
        XCTAssertEqual(BluetoothDeviceKind.classify(classOfDevice: 0, name: "Xbox Wireless Controller"), .gameController)
        XCTAssertEqual(BluetoothDeviceKind.classify(classOfDevice: 0, name: "Logitech Pebble Mouse"), .mouse)
        XCTAssertEqual(BluetoothDeviceKind.classify(classOfDevice: 0, name: "Galaxy Buds2"), .headphones)
        XCTAssertEqual(BluetoothDeviceKind.classify(classOfDevice: 0, name: "Kitchen Speaker"), .speaker)
        XCTAssertEqual(BluetoothDeviceKind.classify(classOfDevice: 0, name: "Thermometer"), .other)
    }

    func testEveryKindHasASymbolThatExists() {
        for kind in BluetoothDeviceKind.allCases {
            XCTAssertNotNil(NSImage(systemSymbolName: kind.symbol, accessibilityDescription: nil), "\(kind)")
        }
    }

    // MARK: - Connection state

    func testLinkFromState() {
        XCTAssertEqual(BluetoothLink(isConnected: true, pending: nil, failed: nil), .connected)
        XCTAssertEqual(BluetoothLink(isConnected: false, pending: nil, failed: nil), .disconnected)
        // An operation in flight wins over everything.
        XCTAssertEqual(BluetoothLink(isConnected: false, pending: true, failed: true), .connecting)
        XCTAssertEqual(BluetoothLink(isConnected: true, pending: false, failed: nil), .disconnecting)
        // A failure shows only while the device is still where it was.
        XCTAssertEqual(BluetoothLink(isConnected: false, pending: nil, failed: true), .connectFailed)
        XCTAssertEqual(BluetoothLink(isConnected: true, pending: nil, failed: true), .connected)
        XCTAssertEqual(BluetoothLink(isConnected: true, pending: nil, failed: false), .disconnectFailed)
        XCTAssertEqual(BluetoothLink(isConnected: false, pending: nil, failed: false), .disconnected)
    }

    func testLinkCheckMarkAndClick() {
        XCTAssertTrue(BluetoothLink.connected.isChecked)
        XCTAssertTrue(BluetoothLink.disconnectFailed.isChecked)
        XCTAssertFalse(BluetoothLink.connectFailed.isChecked)
        XCTAssertEqual(BluetoothLink.connected.clickConnects, false)
        XCTAssertEqual(BluetoothLink.disconnected.clickConnects, true)
        XCTAssertEqual(BluetoothLink.connectFailed.clickConnects, true)      // try again
        XCTAssertEqual(BluetoothLink.disconnectFailed.clickConnects, false)
        XCTAssertNil(BluetoothLink.connecting.clickConnects)                 // no double-clicks
        XCTAssertNil(BluetoothLink.disconnecting.clickConnects)
        XCTAssertEqual(BluetoothLink.connecting.note, "Connecting…")
        XCTAssertEqual(BluetoothLink.connectFailed.note, "Couldn’t connect")
        XCTAssertNil(BluetoothLink.connected.note)
    }

    func testOperationSuccess() {
        let failure = IOReturn(bitPattern: 0xE00002BC)   // kIOReturnError
        XCTAssertTrue(BluetoothLink.succeeded(result: kIOReturnSuccess, wantConnected: true, isConnectedAfter: true))
        XCTAssertTrue(BluetoothLink.succeeded(result: kIOReturnSuccess, wantConnected: true, isConnectedAfter: false))
        // openConnection on a live link reports "already exists" as an error.
        XCTAssertTrue(BluetoothLink.succeeded(result: failure, wantConnected: true, isConnectedAfter: true))
        XCTAssertFalse(BluetoothLink.succeeded(result: failure, wantConnected: true, isConnectedAfter: false))
        XCTAssertTrue(BluetoothLink.succeeded(result: failure, wantConnected: false, isConnectedAfter: false))
        XCTAssertFalse(BluetoothLink.succeeded(result: failure, wantConnected: false, isConnectedAfter: true))
    }

    // MARK: - Rows

    private func device(_ name: String, _ address: String = "00-00-00-00-00-01",
                        connected: Bool) -> BluetoothDeviceSnapshot {
        BluetoothDeviceSnapshot(address: address, name: name, classOfDevice: 0x240418, isConnected: connected)
    }

    func testRowDetail() {
        let batteries = ["Headphones": 85]
        let connected = BluetoothRow.make(device("Headphones", connected: true), pending: nil, failed: nil, batteries: batteries)
        XCTAssertEqual(connected.detail, "85%")
        XCTAssertEqual(connected.kind, .headphones)
        // A disconnected device's last figure is not shown.
        let off = BluetoothRow.make(device("Headphones", connected: false), pending: nil, failed: nil, batteries: batteries)
        XCTAssertNil(off.battery)
        XCTAssertNil(off.detail)
        // What is happening outranks the battery.
        let leaving = BluetoothRow.make(device("Headphones", connected: true), pending: false, failed: nil, batteries: batteries)
        XCTAssertEqual(leaving.detail, "Disconnecting…")
        let unknown = BluetoothRow.make(device("Other", connected: true), pending: nil, failed: nil, batteries: batteries)
        XCTAssertNil(unknown.detail)
    }

    func testRowsSortConnectedFirstThenByName() {
        let rows = [
            BluetoothRow.make(device("Speaker 10", "A", connected: false), pending: nil, failed: nil, batteries: [:]),
            BluetoothRow.make(device("speaker 2", "B", connected: false), pending: nil, failed: nil, batteries: [:]),
            BluetoothRow.make(device("Zed", "C", connected: true), pending: nil, failed: nil, batteries: [:]),
            BluetoothRow.make(device("Mouse", "E", connected: false), pending: nil, failed: nil, batteries: [:]),
            BluetoothRow.make(device("Mouse", "D", connected: false), pending: nil, failed: nil, batteries: [:]),
        ]
        XCTAssertEqual(BluetoothRow.sorted(rows).map(\.address), ["C", "D", "E", "B", "A"])
    }

    // MARK: - Availability

    func testAvailability() {
        typealias A = BluetoothAvailability
        // No usage string (a bare `swift run` binary): never ask.
        XCTAssertEqual(A.resolve(canAsk: false, authorization: .allowedAlways, radio: .poweredOn), .installedAppOnly)
        XCTAssertEqual(A.resolve(canAsk: true, authorization: .notDetermined, radio: nil), .needsPermission)
        XCTAssertEqual(A.resolve(canAsk: true, authorization: .denied, radio: .poweredOn), .denied)
        XCTAssertEqual(A.resolve(canAsk: true, authorization: .restricted, radio: nil), .restricted)
        XCTAssertEqual(A.resolve(canAsk: true, authorization: .allowedAlways, radio: nil), .starting)
        XCTAssertEqual(A.resolve(canAsk: true, authorization: .allowedAlways, radio: .unknown), .starting)
        XCTAssertEqual(A.resolve(canAsk: true, authorization: .allowedAlways, radio: .resetting), .starting)
        XCTAssertEqual(A.resolve(canAsk: true, authorization: .allowedAlways, radio: .poweredOff), .off)
        XCTAssertEqual(A.resolve(canAsk: true, authorization: .allowedAlways, radio: .unsupported), .unsupported)
        XCTAssertEqual(A.resolve(canAsk: true, authorization: .allowedAlways, radio: .unauthorized), .denied)
        XCTAssertEqual(A.resolve(canAsk: true, authorization: .allowedAlways, radio: .poweredOn), .ready)
    }

    func testAvailabilityRows() {
        XCTAssertNil(BluetoothAvailability.ready.message)
        XCTAssertNil(BluetoothAvailability.needsPermission.message)   // the "Allow…" row says it
        XCTAssertEqual(BluetoothAvailability.off.message, "Bluetooth is off")
        // The two states the user can fix in System Settings say where.
        XCTAssertNotNil(BluetoothAvailability.off.settingsHint)
        XCTAssertNotNil(BluetoothAvailability.denied.settingsHint)
        XCTAssertNil(BluetoothAvailability.restricted.settingsHint)
    }

    // MARK: - Battery (GATT Battery Level)

    func testBatteryLevelParsing() {
        XCTAssertEqual(BluetoothCentral.level(from: Data([85])), 85)
        XCTAssertEqual(BluetoothCentral.level(from: Data([0])), 0)
        XCTAssertEqual(BluetoothCentral.level(from: Data([100])), 100)
        XCTAssertEqual(BluetoothCentral.level(from: Data([85, 1])), 85)
        XCTAssertNil(BluetoothCentral.level(from: Data([101])))        // out of range
        XCTAssertNil(BluetoothCentral.level(from: Data()))
        XCTAssertNil(BluetoothCentral.level(from: nil))
        // A slice whose indices don't start at 0.
        XCTAssertEqual(BluetoothCentral.level(from: Data([1, 42, 3])[1...]), 42)
    }

    func testBatteryLevelsByNameDropAmbiguity() {
        let levels = BluetoothCentral.levelsByName([
            .init(name: "Mouse", level: 40),
            .init(name: "Keyboard", level: 90),
            .init(name: "Keyboard", level: 10),   // two "Keyboard"s: which is which?
            .init(name: nil, level: 50),
            .init(name: "", level: 60),
        ])
        XCTAssertEqual(levels, ["Mouse": 40])
    }
}
