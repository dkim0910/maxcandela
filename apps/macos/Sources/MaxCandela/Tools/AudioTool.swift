import AppKit
import CoreAudio

/// CoreAudio device plumbing, kept apart from the menu. Public HAL API.
enum AudioDevices {
    struct Device: Equatable {
        let id: AudioDeviceID
        let name: String
        let hasInput: Bool
        let hasOutput: Bool
    }

    private static func address(_ selector: AudioObjectPropertySelector,
                                scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    static func all() -> [Device] {
        var addr = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { id in
            guard let name = name(of: id) else { return nil }
            let input = channelCount(id, scope: kAudioObjectPropertyScopeInput) > 0
            let output = channelCount(id, scope: kAudioObjectPropertyScopeOutput) > 0
            return input || output ? Device(id: id, name: name, hasInput: input, hasOutput: output) : nil
        }
    }

    private static func name(of id: AudioDeviceID) -> String? {
        var addr = address(kAudioObjectPropertyName)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &name) == noErr else { return nil }
        return name?.takeRetainedValue() as String?
    }

    private static func channelCount(_ id: AudioDeviceID, scope: AudioObjectPropertyScope) -> Int {
        var addr = address(kAudioDevicePropertyStreamConfiguration, scope: scope)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr, size > 0 else { return 0 }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, raw) == noErr else { return 0 }
        let list = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        return list.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    static func defaultDevice(input: Bool) -> AudioDeviceID? {
        var addr = address(input ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice)
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id) == noErr,
              id != 0 else { return nil }
        return id
    }

    @discardableResult
    static func setDefault(_ id: AudioDeviceID, input: Bool) -> Bool {
        var addr = address(input ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice)
        var id = id
        return AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil,
                                          UInt32(MemoryLayout<AudioDeviceID>.size), &id) == noErr
    }

    /// nil when the device has no mute control (some USB microphones).
    static func isInputMuted(_ id: AudioDeviceID) -> Bool? {
        var addr = address(kAudioDevicePropertyMute, scope: kAudioObjectPropertyScopeInput)
        guard AudioObjectHasProperty(id, &addr) else { return nil }
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &muted) == noErr else { return nil }
        return muted != 0
    }

    @discardableResult
    static func setInputMuted(_ muted: Bool, on id: AudioDeviceID) -> Bool {
        var addr = address(kAudioDevicePropertyMute, scope: kAudioObjectPropertyScopeInput)
        var value: UInt32 = muted ? 1 : 0
        return AudioObjectSetPropertyData(id, &addr, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value) == noErr
    }
}

/// Sound: switch the output and input device, and mute the microphone,
/// without opening System Settings. Changing the default device and the
/// hardware mute are HAL property writes — no microphone access is requested
/// or needed, because no audio is ever read.
///
/// ⚠️ Whether the sandbox lets these *writes* through is unverified; the
/// device list was checked on the dev Mac (`ToolsTests`).
final class AudioTool: MenuTool {
    let menuItem = NSMenuItem(title: "Sound", action: nil, keyEquivalent: "")
    var onStatusChange: (() -> Void)?
    private let submenu = NSMenu()

    init() {
        menuItem.submenu = submenu
        menuItem.symbol("speaker.wave.2")
    }

    func menuWillOpen() { rebuild() }

    private func rebuild() {
        submenu.removeAllItems()
        let devices = AudioDevices.all()
        let output = AudioDevices.defaultDevice(input: false)
        let input = AudioDevices.defaultDevice(input: true)

        submenu.addItem(.sectionHeader(title: "Output"))
        for device in devices where device.hasOutput {
            submenu.addItem(row(device, selected: device.id == output, input: false))
        }
        submenu.addItem(.separator())
        submenu.addItem(.sectionHeader(title: "Input"))
        for device in devices where device.hasInput {
            submenu.addItem(row(device, selected: device.id == input, input: true))
        }
        if let input, let muted = AudioDevices.isInputMuted(input) {
            submenu.addItem(.separator())
            let mute = NSMenuItem(title: "Mute Microphone", action: #selector(toggleMute), keyEquivalent: "")
            mute.target = self
            mute.state = muted ? .on : .off
            submenu.addItem(mute.symbol(muted ? "mic.slash" : "mic"))
        }
    }

    private func row(_ device: AudioDevices.Device, selected: Bool, input: Bool) -> NSMenuItem {
        let item = NSMenuItem(title: device.name, action: #selector(select(_:)), keyEquivalent: "")
        item.target = self
        item.tag = Int(device.id)
        item.representedObject = input
        item.state = selected ? .on : .off
        return item
    }

    @objc private func select(_ sender: NSMenuItem) {
        guard let input = sender.representedObject as? Bool else { return }
        if !AudioDevices.setDefault(AudioDeviceID(sender.tag), input: input) { NSSound.beep() }
    }

    @objc private func toggleMute() {
        guard let input = AudioDevices.defaultDevice(input: true),
              let muted = AudioDevices.isInputMuted(input) else { return }
        if !AudioDevices.setInputMuted(!muted, on: input) { NSSound.beep() }
    }
}
