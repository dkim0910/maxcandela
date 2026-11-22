// TapSpike — does a Core Audio process tap work for MaxCandela's App Volume,
// inside the App Sandbox, and what does macOS ask the user?
//
// It taps one process by PID with the same recipe App Volume uses
// (apps/macos/Sources/MaxCandela/Tools/ProcessTap.swift):
//   - CATapDescription(stereoMixdownOfProcesses:), private, muted-when-tapped;
//   - a private aggregate device: the default output device (clock) + the tap,
//     drift compensation on the tap, tap auto-start;
//   - the output device's own inputs switched off with
//     kAudioDevicePropertyIOProcStreamUsage (no microphone use);
//   - a C IO proc that copies the tap to the output at the chosen gain, with
//     App Volume's soft limiter above 100%;
// plays for N seconds, tears everything down, and prints the OSStatus of every
// Core Audio call.
//
//   TapSpike list
//       Process objects (PID, bundle ID, playing?), devices and taps — run it
//       before and after a test to spot anything left behind.
//   TapSpike <pid> <percent> <seconds> [--unmuted] [--crash]
//       percent: 0–200 on App Volume's curve, gain = (percent/100)²
//       (50% = −12 dB, 200% = +12 dB).
//       --unmuted  CATapUnmuted: the app keeps playing normally and you also
//                  hear our copy — proves capture without muting the original.
//       --crash    abort() after <seconds> with no teardown, to check the app is
//                  heard again on its own and nothing is left (run `list` after).
//
// Run it with ./run-sandboxed.sh: a bare binary started from Terminal is not
// sandboxed, and macOS attributes its permission prompt to Terminal.

import CoreAudio
import Foundation
import os

setvbuf(stdout, nil, _IONBF, 0)
let logger = Logger(subsystem: "com.maxcandela.tapspike", category: "spike")

/// Every line goes to stdout and to the unified log (`log show --predicate
/// 'subsystem == "com.maxcandela.tapspike"'`), in case stdout is lost.
func say(_ line: String) {
    print(line)
    logger.notice("\(line, privacy: .public)")
}

func code(_ status: OSStatus) -> String {
    let bytes = withUnsafeBytes(of: UInt32(bitPattern: status).bigEndian) { Array($0) }
    if status != 0, bytes.allSatisfy({ (0x20...0x7E).contains($0) }) {
        return "'\(String(decoding: bytes, as: UTF8.self))' (\(status))"
    }
    return "\(status)"
}

@discardableResult
func step(_ label: String, _ status: OSStatus, _ detail: String = "") -> Bool {
    say("\(status == noErr ? "[ ok ]" : "[FAIL]") \(label): \(code(status))\(detail.isEmpty ? "" : " — \(detail)")")
    return status == noErr
}

func ms(since start: Date) -> String { String(format: "%.1f ms", Date().timeIntervalSince(start) * 1000) }

func dB(_ amplitude: Float) -> String {
    amplitude > 0 ? String(format: "%.1f dBFS", 20 * log10(amplitude)) : "-inf"
}

// MARK: - HAL helpers

let system = AudioObjectID(kAudioObjectSystemObject)

func address(_ selector: AudioObjectPropertySelector,
             _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
}

func get<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
            _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, _ initial: T) -> (OSStatus, T) {
    var addr = address(selector, scope)
    var value = initial
    var size = UInt32(MemoryLayout<T>.size)
    let status = withUnsafeMutablePointer(to: &value) { AudioObjectGetPropertyData(object, &addr, 0, nil, &size, $0) }
    return (status, value)
}

func getArray<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
                 _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, _ zero: T) -> (OSStatus, [T]) {
    var addr = address(selector, scope)
    var size: UInt32 = 0
    var status = AudioObjectGetPropertyDataSize(object, &addr, 0, nil, &size)
    let count = Int(size) / MemoryLayout<T>.stride
    guard status == noErr, count > 0 else { return (status, []) }
    var items = [T](repeating: zero, count: count)
    status = items.withUnsafeMutableBufferPointer { AudioObjectGetPropertyData(object, &addr, 0, nil, &size, $0.baseAddress!) }
    return (status, status == noErr ? Array(items.prefix(Int(size) / MemoryLayout<T>.stride)) : [])
}

func getString(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> (OSStatus, String?) {
    var addr = address(selector)
    var string: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    let status = AudioObjectGetPropertyData(object, &addr, 0, nil, &size, &string)
    return (status, status == noErr ? string?.takeRetainedValue() as String? : nil)
}

func streamChannelCounts(_ device: AudioObjectID, _ scope: AudioObjectPropertyScope) -> [Int] {
    var addr = address(kAudioDevicePropertyStreamConfiguration, scope)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(device, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
    let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
    defer { raw.deallocate() }
    guard AudioObjectGetPropertyData(device, &addr, 0, nil, &size, raw) == noErr else { return [] }
    return UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self)).map { Int($0.mNumberChannels) }
}

func streamFormats(_ device: AudioObjectID, _ scope: AudioObjectPropertyScope) -> [AudioStreamBasicDescription] {
    getArray(device, kAudioDevicePropertyStreams, scope, AudioStreamID(0)).1.map {
        get($0, kAudioStreamPropertyVirtualFormat, kAudioObjectPropertyScopeGlobal, AudioStreamBasicDescription()).1
    }
}

func describe(_ f: AudioStreamBasicDescription) -> String {
    let kind = f.mFormatFlags & kAudioFormatFlagIsFloat != 0 ? "float" : "int"
    let layout = f.mFormatFlags & kAudioFormatFlagIsNonInterleaved != 0 ? "non-interleaved" : "interleaved"
    return "\(Int(f.mSampleRate)) Hz, \(f.mChannelsPerFrame) ch, \(f.mBitsPerChannel)-bit \(kind), \(layout)"
}

func isFloat32(_ f: AudioStreamBasicDescription) -> Bool {
    f.mFormatID == kAudioFormatLinearPCM && f.mFormatFlags & kAudioFormatFlagIsFloat != 0
        && f.mFormatFlags & kAudioFormatFlagIsBigEndian == 0 && f.mBitsPerChannel == 32
}

let isSandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil

// MARK: - Render (same arithmetic as AppVolumeDSP, plus diagnostics)

struct SpikeState {
    var targetGain: Float
    var gain: Float
    var reduction: Float = 1
    var smoothing: Float
    var release: Float
    var threshold: Float = 0.708     // −3 dBFS, as App Volume
    var ceiling: Float = 0.944       // −0.5 dBFS
    var tapIndex: Int32
    var leftBuffer: Int32
    var leftChannel: Int32
    var rightBuffer: Int32
    var rightChannel: Int32
    var callbacks: UInt32 = 0
    var audible: UInt32 = 0
    var peakIn: Float = 0
    var peakOut: Float = 0
    var minReduction: Float = 1
    var lastFrames: UInt32 = 0
}

func render(_ input: UnsafePointer<AudioBufferList>, _ output: UnsafeMutablePointer<AudioBufferList>,
            _ s: UnsafeMutablePointer<SpikeState>) {
    let outs = UnsafeMutableAudioBufferListPointer(output)
    var i = 0
    while i < outs.count {
        if let d = outs[i].mData { memset(d, 0, Int(outs[i].mDataByteSize)) }
        i += 1
    }
    s.pointee.callbacks &+= 1
    let ins = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
    let ti = Int(s.pointee.tapIndex)
    guard ti >= 0, ti < ins.count, let tapData = ins[ti].mData else { return }
    let tc = max(1, Int(ins[ti].mNumberChannels))
    var frames = Int(ins[ti].mDataByteSize) / (4 * tc)
    let li = Int(s.pointee.leftBuffer)
    guard li >= 0, li < outs.count, let lData = outs[li].mData else { return }
    let ls = max(1, Int(outs[li].mNumberChannels))
    guard Int(s.pointee.leftChannel) < ls else { return }
    frames = min(frames, Int(outs[li].mDataByteSize) / (4 * ls))
    let left = lData.assumingMemoryBound(to: Float.self) + Int(s.pointee.leftChannel)
    var right: UnsafeMutablePointer<Float>?
    var rs = 1
    let ri = Int(s.pointee.rightBuffer)
    if ri >= 0, ri < outs.count, let rData = outs[ri].mData {
        rs = max(1, Int(outs[ri].mNumberChannels))
        if Int(s.pointee.rightChannel) < rs {
            frames = min(frames, Int(outs[ri].mDataByteSize) / (4 * rs))
            right = rData.assumingMemoryBound(to: Float.self) + Int(s.pointee.rightChannel)
        }
    }
    s.pointee.lastFrames = UInt32(max(0, frames))
    let input = tapData.assumingMemoryBound(to: Float.self)
    let target = s.pointee.targetGain, smoothing = s.pointee.smoothing, release = s.pointee.release
    let t = s.pointee.threshold, c = s.pointee.ceiling
    var gain = s.pointee.gain, reduction = s.pointee.reduction
    var peakIn = s.pointee.peakIn, peakOut = s.pointee.peakOut, minReduction = s.pointee.minReduction
    var heard = false
    var f = 0
    while f < frames {
        let inL = input[f * tc], inR = tc > 1 ? input[f * tc + 1] : inL
        if inL != 0 || inR != 0 { heard = true }
        peakIn = max(peakIn, max(abs(inL), abs(inR)))
        gain += (target - gain) * smoothing
        var l = inL * gain, r = inR * gain
        var required: Float = 1
        if gain > 1 {
            let x = max(abs(l), abs(r))
            if x > t, x.isFinite { required = (t + (c - t) * tanh((x - t) / (c - t))) / x } else if !x.isFinite { required = 0 }
        }
        reduction = required < reduction ? required : required + (reduction - required) * release
        minReduction = min(minReduction, reduction)
        l *= reduction
        r *= reduction
        if let right {
            left[f * ls] = l
            right[f * rs] = r
            peakOut = max(peakOut, max(abs(l), abs(r)))
        } else {
            left[f * ls] = 0.5 * (l + r)
            peakOut = max(peakOut, abs(0.5 * (l + r)))
        }
        f += 1
    }
    s.pointee.gain = gain
    s.pointee.reduction = reduction
    s.pointee.peakIn = peakIn
    s.pointee.peakOut = peakOut
    s.pointee.minReduction = minReduction
    if heard { s.pointee.audible &+= 1 }
}

/// A C function pointer, as in App Volume: no Swift closure context on the IO thread.
let ioProc: AudioDeviceIOProc = { _, _, input, _, output, _, clientData in
    guard let clientData else { return noErr }
    render(input, output, clientData.assumingMemoryBound(to: SpikeState.self))
    return noErr
}

// MARK: - list

@available(macOS 14.2, *)
func listEverything() {
    say("macOS \(ProcessInfo.processInfo.operatingSystemVersionString), sandboxed: \(isSandboxed ? "yes" : "no")")
    let (ds, dev) = get(system, kAudioHardwarePropertyDefaultOutputDevice, kAudioObjectPropertyScopeGlobal, AudioDeviceID(0))
    step("default output device", ds, "id \(dev) \"\(getString(dev, kAudioObjectPropertyName).1 ?? "?")\" uid \(getString(dev, kAudioDevicePropertyDeviceUID).1 ?? "?")")
    say("   input streams \(streamChannelCounts(dev, kAudioObjectPropertyScopeInput)), output streams \(streamChannelCounts(dev, kAudioObjectPropertyScopeOutput)) (channels per stream)")

    let (devs, devices) = getArray(system, kAudioHardwarePropertyDevices, kAudioObjectPropertyScopeGlobal, AudioObjectID(0))
    step("device list", devs, "\(devices.count) devices")
    for d in devices {
        say("   device \(d): \"\(getString(d, kAudioObjectPropertyName).1 ?? "?")\" uid \(getString(d, kAudioDevicePropertyDeviceUID).1 ?? "?")")
    }
    let (ts, taps) = getArray(system, kAudioHardwarePropertyTapList, kAudioObjectPropertyScopeGlobal, AudioObjectID(0))
    step("tap list (only public taps are visible)", ts, "\(taps)")

    let (ps, processes) = getArray(system, kAudioHardwarePropertyProcessObjectList, kAudioObjectPropertyScopeGlobal, AudioObjectID(0))
    step("process object list", ps, "\(processes.count) processes")
    for p in processes {
        let pid = get(p, kAudioProcessPropertyPID, kAudioObjectPropertyScopeGlobal, pid_t(-1)).1
        let out = get(p, kAudioProcessPropertyIsRunningOutput, kAudioObjectPropertyScopeGlobal, UInt32(0)).1
        let inp = get(p, kAudioProcessPropertyIsRunningInput, kAudioObjectPropertyScopeGlobal, UInt32(0)).1
        say("   object \(p)  pid \(pid)  \(out != 0 ? "PLAYING" : "-------")  \(inp != 0 ? "recording" : "")  \(getString(p, kAudioProcessPropertyBundleID).1 ?? "(no bundle ID)")")
    }
}

// MARK: - tap

/// Everything created, so teardown — or a refusal half-way — destroys exactly that.
final class Created {
    var tap = AudioObjectID(kAudioObjectUnknown)
    var aggregate = AudioObjectID(kAudioObjectUnknown)
    var proc: AudioDeviceIOProcID?
    var started = false

    @available(macOS 14.2, *)
    func teardown() {
        say("— teardown —")
        if let proc {
            if started { step("AudioDeviceStop", AudioDeviceStop(aggregate, proc)) }
            step("AudioDeviceDestroyIOProcID", AudioDeviceDestroyIOProcID(aggregate, proc))
        }
        if aggregate != kAudioObjectUnknown {
            step("AudioHardwareDestroyAggregateDevice", AudioHardwareDestroyAggregateDevice(aggregate))
        }
        if tap != kAudioObjectUnknown {
            step("AudioHardwareDestroyProcessTap", AudioHardwareDestroyProcessTap(tap))
        }
        let devices = getArray(system, kAudioHardwarePropertyDevices, kAudioObjectPropertyScopeGlobal, AudioObjectID(0)).1
        let taps = getArray(system, kAudioHardwarePropertyTapList, kAudioObjectPropertyScopeGlobal, AudioObjectID(0)).1
        say("   aggregate \(aggregate) still listed: \(devices.contains(aggregate)), tap \(tap) still listed: \(taps.contains(tap))")
        proc = nil
        started = false
    }
}

@available(macOS 14.2, *)
func runTap(pid: pid_t, percent: Double, seconds: Double, unmuted: Bool, crash: Bool) -> Int32 {
    let p = max(0, min(200, percent)) / 100
    let gain = Float(p * p)
    say("TapSpike: pid \(pid), \(percent)% → gain \(gain) (\(dB(gain)) relative), \(seconds) s, "
        + "\(unmuted ? "CATapUnmuted" : "CATapMutedWhenTapped"), sandboxed: \(isSandboxed ? "yes" : "no")")

    // 1. PID → Core Audio process object.
    var addr = address(kAudioHardwarePropertyTranslatePIDToProcessObject)
    var qualifier = pid
    var object = AudioObjectID(kAudioObjectUnknown)
    var size = UInt32(MemoryLayout<AudioObjectID>.size)
    let ts = AudioObjectGetPropertyData(system, &addr, UInt32(MemoryLayout<pid_t>.size), &qualifier, &size, &object)
    step("translate PID → process object", ts, "object \(object)")
    guard ts == noErr, object != kAudioObjectUnknown else {
        say("No Core Audio process for PID \(pid). A process appears only once it has used audio — start playback, then run `list`.")
        return 1
    }
    say("   bundle ID \(getString(object, kAudioProcessPropertyBundleID).1 ?? "(none)"), playing now: "
        + "\(get(object, kAudioProcessPropertyIsRunningOutput, kAudioObjectPropertyScopeGlobal, UInt32(0)).1 != 0)")

    // 2. The output device.
    let (ds, device) = get(system, kAudioHardwarePropertyDefaultOutputDevice, kAudioObjectPropertyScopeGlobal, AudioDeviceID(0))
    let (us, outputUID) = getString(device, kAudioDevicePropertyDeviceUID)
    step("default output device", ds, "id \(device) \"\(getString(device, kAudioObjectPropertyName).1 ?? "?")\"")
    step("   its UID", us, outputUID ?? "nil")
    guard ds == noErr, us == noErr, let outputUID else { return 1 }
    let deviceInputs = getArray(device, kAudioDevicePropertyStreams, kAudioObjectPropertyScopeInput, AudioStreamID(0)).1.count
    let preferred = getArray(device, kAudioDevicePropertyPreferredChannelsForStereo, kAudioObjectPropertyScopeOutput, UInt32(0)).1
    say("   device input streams: \(deviceInputs), output channels per stream: \(streamChannelCounts(device, kAudioObjectPropertyScopeOutput)), preferred stereo: \(preferred)")

    let created = Created()

    // 3. The tap.
    let description = CATapDescription(stereoMixdownOfProcesses: [object])
    description.uuid = UUID()
    description.name = "TapSpike"
    description.isPrivate = true
    description.muteBehavior = unmuted ? .unmuted : .mutedWhenTapped
    var start = Date()
    var tap = AudioObjectID(kAudioObjectUnknown)
    let cs = AudioHardwareCreateProcessTap(description, &tap)
    step("AudioHardwareCreateProcessTap", cs, "tap \(tap), \(ms(since: start))")
    guard cs == noErr, tap != kAudioObjectUnknown else { return 1 }
    created.tap = tap
    let (tus, tapUID) = getString(tap, kAudioTapPropertyUID)
    step("   tap UID", tus, tapUID ?? "nil")
    let (tfs, tapFormat) = get(tap, kAudioTapPropertyFormat, kAudioObjectPropertyScopeGlobal, AudioStreamBasicDescription())
    step("   tap format", tfs, describe(tapFormat))
    guard tus == noErr, let tapUID else { created.teardown(); return 1 }

    // 4. The aggregate device.
    let composition: [String: Any] = [
        kAudioAggregateDeviceNameKey: "TapSpike",
        kAudioAggregateDeviceUIDKey: "com.maxcandela.tapspike.\(UUID().uuidString)",
        kAudioAggregateDeviceMainSubDeviceKey: outputUID,
        kAudioAggregateDeviceIsPrivateKey: 1,
        kAudioAggregateDeviceIsStackedKey: 0,
        kAudioAggregateDeviceTapAutoStartKey: 1,
        kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
        kAudioAggregateDeviceTapListKey: [[kAudioSubTapUIDKey: tapUID, kAudioSubTapDriftCompensationKey: 1]],
    ]
    start = Date()
    var aggregate = AudioObjectID(kAudioObjectUnknown)
    let ags = AudioHardwareCreateAggregateDevice(composition as CFDictionary, &aggregate)
    step("AudioHardwareCreateAggregateDevice", ags, "device \(aggregate), \(ms(since: start))")
    guard ags == noErr, aggregate != kAudioObjectUnknown else { created.teardown(); return 1 }
    created.aggregate = aggregate

    // 5. Layout: which input stream is the tap, where left/right go.
    let inputFormats = streamFormats(aggregate, kAudioObjectPropertyScopeInput)
    let outputFormats = streamFormats(aggregate, kAudioObjectPropertyScopeOutput)
    let outputChannels = streamChannelCounts(aggregate, kAudioObjectPropertyScopeOutput)
    say("   aggregate input streams: \(inputFormats.map(describe))")
    say("   aggregate output streams: \(outputFormats.map(describe)) — channels \(outputChannels)")
    let rate = get(aggregate, kAudioDevicePropertyNominalSampleRate, kAudioObjectPropertyScopeGlobal, Float64(0)).1
    say("   aggregate nominal sample rate: \(rate)")
    guard inputFormats.count == deviceInputs + 1 else {
        say("[FAIL] layout: expected \(deviceInputs + 1) input streams (device's + the tap), got \(inputFormats.count). App Volume refuses this layout.")
        created.teardown()
        return 1
    }
    let tapIndex = inputFormats.count - 1
    guard isFloat32(inputFormats[tapIndex]), !outputFormats.isEmpty, outputFormats.allSatisfy(isFloat32) else {
        say("[FAIL] layout: a stream is not 32-bit float. App Volume refuses this.")
        created.teardown()
        return 1
    }
    func location(_ channel: Int) -> (Int, Int)? {
        var remaining = channel
        for (buffer, count) in outputChannels.enumerated() {
            if remaining < count { return (buffer, remaining) }
            remaining -= count
        }
        return nil
    }
    var left = location(0), right = location(1)
    if preferred.count == 2, preferred[0] >= 1, preferred[1] >= 1, preferred[0] != preferred[1],
       let l = location(Int(preferred[0]) - 1), let r = location(Int(preferred[1]) - 1) {
        left = l
        right = r
    }
    guard let left else { say("[FAIL] layout: no output channel"); created.teardown(); return 1 }
    say("   tap = input stream \(tapIndex); left → buffer \(left.0) ch \(left.1); right → \(right.map { "buffer \($0.0) ch \($0.1)" } ?? "none (mono mix)")")

    let sampleRate = rate > 0 ? rate : 48_000
    let state = UnsafeMutablePointer<SpikeState>.allocate(capacity: 1)
    state.initialize(to: SpikeState(
        targetGain: gain, gain: gain,
        smoothing: Float(1 - exp(-1 / (0.010 * sampleRate))),
        release: Float(exp(-1 / (0.150 * sampleRate))),
        tapIndex: Int32(tapIndex), leftBuffer: Int32(left.0), leftChannel: Int32(left.1),
        rightBuffer: Int32(right?.0 ?? -1), rightChannel: Int32(right?.1 ?? 0)))
    // Deliberately never freed: this process exits right after teardown.

    // 6. The IO proc.
    var proc: AudioDeviceIOProcID?
    let ps = AudioDeviceCreateIOProcID(aggregate, ioProc, UnsafeMutableRawPointer(state), &proc)
    step("AudioDeviceCreateIOProcID", ps)
    guard ps == noErr, let proc else { created.teardown(); return 1 }
    created.proc = proc

    // 7. Hardware inputs off (only matters when the output device has some).
    if inputFormats.count > 1 {
        let flags = (0..<inputFormats.count).map { UInt32($0 == tapIndex ? 1 : 0) }
        let flagsOffset = MemoryLayout<UnsafeMutableRawPointer>.size + MemoryLayout<UInt32>.size
        let byteCount = flagsOffset + flags.count * MemoryLayout<UInt32>.size
        let raw = UnsafeMutableRawPointer.allocate(byteCount: byteCount, alignment: MemoryLayout<UnsafeMutableRawPointer>.alignment)
        defer { raw.deallocate() }
        raw.storeBytes(of: unsafeBitCast(proc, to: UnsafeMutableRawPointer.self), as: UnsafeMutableRawPointer.self)
        raw.storeBytes(of: UInt32(flags.count), toByteOffset: MemoryLayout<UnsafeMutableRawPointer>.size, as: UInt32.self)
        for (i, flag) in flags.enumerated() {
            raw.storeBytes(of: flag, toByteOffset: flagsOffset + i * MemoryLayout<UInt32>.size, as: UInt32.self)
        }
        var usage = address(kAudioDevicePropertyIOProcStreamUsage, kAudioObjectPropertyScopeInput)
        let us = AudioObjectSetPropertyData(aggregate, &usage, 0, nil, UInt32(byteCount), raw)
        step("IOProcStreamUsage (inputs \(flags))", us)
        guard us == noErr else {
            say("App Volume refuses to start here: the device's microphone could be switched on.")
            created.teardown()
            return 1
        }
    } else {
        say("   output device has no inputs: stream usage not needed")
    }

    // 8. Start. The first start is where macOS should ask for "System Audio
    //    Recording". If this call blocks until the prompt is answered, or
    //    until the app makes sound (tap auto-start), the time shows it.
    start = Date()
    let ss = AudioDeviceStart(aggregate, proc)
    step("AudioDeviceStart", ss, ms(since: start))
    guard ss == noErr else { created.teardown(); return 1 }
    created.started = true

    // 9. Run, reporting once a second. Ctrl-C (or SIGTERM) ends early, with teardown.
    signal(SIGINT, SIG_IGN)
    signal(SIGTERM, SIG_IGN)
    var stopRequested = false
    let sources = [SIGINT, SIGTERM].map { number -> DispatchSourceSignal in
        let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
        source.setEventHandler { stopRequested = true }
        source.resume()
        return source
    }
    let began = Date()
    let end = began.addingTimeInterval(seconds)
    var lastCallbacks: UInt32 = 0
    while Date() < end && !stopRequested {
        RunLoop.current.run(until: min(end, Date().addingTimeInterval(1)))
        let s = state.pointee
        let playing = get(object, kAudioProcessPropertyIsRunningOutput, kAudioObjectPropertyScopeGlobal, UInt32(0)).1 != 0
        say(String(format: "   t=%4.1fs  cycles %u (+%u)  audible %u  frames/cycle %u  in %@  out %@  limiter %@  app playing: %@",
                   Date().timeIntervalSince(began), s.callbacks, s.callbacks &- lastCallbacks, s.audible, s.lastFrames,
                   dB(s.peakIn), dB(s.peakOut), dB(s.minReduction), playing ? "yes" : "no"))
        lastCallbacks = s.callbacks
    }
    sources.forEach { $0.cancel() }

    let s = state.pointee
    if s.callbacks == 0 {
        say("VERDICT: no IO cycles. With tap auto-start, IO runs only while the tapped app plays — was it playing?")
    } else if s.audible == 0 {
        say("VERDICT: the tap ran but delivered only silence. If the app was audibly playing, this is the expected "
            + "look of a refused permission: System Settings ▸ Privacy & Security ▸ Screen & System Audio Recording.")
    } else {
        say("VERDICT: the tap delivered audio (\(s.audible) of \(s.callbacks) cycles had sound; peak in \(dB(s.peakIn)), out \(dB(s.peakOut))).")
    }

    if crash {
        say("--crash: abort() now, without teardown. Afterwards the app should be audible on its own; run `list` to check nothing named TapSpike is left.")
        abort()
    }
    created.teardown()
    return 0
}

// MARK: - main

@available(macOS 14.2, *)
func main(_ arguments: [String]) -> Int32 {
    if arguments.first == "list" {
        listEverything()
        return 0
    }
    let numbers = arguments.filter { !$0.hasPrefix("--") }
    guard numbers.count == 3, let pid = pid_t(numbers[0]),
          let percent = Double(numbers[1]), let seconds = Double(numbers[2]) else {
        say("usage: TapSpike list")
        say("       TapSpike <pid> <percent 0-200> <seconds> [--unmuted] [--crash]")
        return 2
    }
    return runTap(pid: pid, percent: percent, seconds: seconds,
                  unmuted: arguments.contains("--unmuted"), crash: arguments.contains("--crash"))
}

if #available(macOS 14.2, *) {
    exit(main(Array(CommandLine.arguments.dropFirst()).filter { !$0.hasPrefix("-psn_") }))
} else {
    say("Process taps need macOS 14.2 or later.")
    exit(2)
}
