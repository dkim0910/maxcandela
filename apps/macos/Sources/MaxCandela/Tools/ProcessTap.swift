import AppKit
import CoreAudio

/// Thin, typed wrappers over the HAL property calls App Volume needs.
@available(macOS 14.2, *)
enum TapHAL {
    static let system = AudioObjectID(kAudioObjectSystemObject)

    static func address(_ selector: AudioObjectPropertySelector,
                        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    static func value<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
                         scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                         initial: T) -> (status: OSStatus, value: T) {
        var addr = address(selector, scope: scope)
        var value = initial
        var size = UInt32(MemoryLayout<T>.size)
        let status = withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(object, &addr, 0, nil, &size, $0)
        }
        return (status, value)
    }

    static func array<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
                         scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                         of type: T.Type, zero: T) -> [T] {
        var addr = address(selector, scope: scope)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(object, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
        let count = Int(size) / MemoryLayout<T>.stride
        guard count > 0 else { return [] }
        var items = [T](repeating: zero, count: count)
        let status = items.withUnsafeMutableBufferPointer { buffer in
            AudioObjectGetPropertyData(object, &addr, 0, nil, &size, buffer.baseAddress!)
        }
        guard status == noErr else { return [] }
        return Array(items.prefix(Int(size) / MemoryLayout<T>.stride))
    }

    /// A CFString property the caller owns (bundle IDs, UIDs).
    static func string(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> (status: OSStatus, value: String?) {
        var addr = address(selector)
        var string: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(object, &addr, 0, nil, &size, &string)
        guard status == noErr else { return (status, nil) }
        return (status, string?.takeRetainedValue() as String?)
    }

    static func streamCount(_ device: AudioObjectID, scope: AudioObjectPropertyScope) -> Int {
        array(device, kAudioDevicePropertyStreams, scope: scope, of: AudioStreamID.self, zero: 0).count
    }

    /// Channels per stream, in the order an IO proc receives the buffers.
    static func streamChannelCounts(_ device: AudioObjectID, scope: AudioObjectPropertyScope) -> [Int] {
        var addr = address(kAudioDevicePropertyStreamConfiguration, scope: scope)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(device, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(device, &addr, 0, nil, &size, raw) == noErr else { return [] }
        let list = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        return list.map { Int($0.mNumberChannels) }
    }

    static func streamFormats(_ device: AudioObjectID, scope: AudioObjectPropertyScope) -> [AudioStreamBasicDescription] {
        array(device, kAudioDevicePropertyStreams, scope: scope, of: AudioStreamID.self, zero: 0).map {
            value($0, kAudioStreamPropertyVirtualFormat, initial: AudioStreamBasicDescription()).value
        }
    }

    static func preferredStereo(_ device: AudioObjectID) -> (left: UInt32, right: UInt32)? {
        let pair = array(device, kAudioDevicePropertyPreferredChannelsForStereo,
                         scope: kAudioObjectPropertyScopeOutput, of: UInt32.self, zero: 0)
        return pair.count == 2 ? (pair[0], pair[1]) : nil
    }
}

/// The audio clients on the system right now.
@available(macOS 14.2, *)
enum AudioProcessList {
    static func current() -> [AudioProcessInfo] {
        TapHAL.array(TapHAL.system, kAudioHardwarePropertyProcessObjectList,
                     of: AudioObjectID.self, zero: 0).compactMap { object in
            let pid = TapHAL.value(object, kAudioProcessPropertyPID, initial: pid_t(-1))
            guard pid.status == noErr, pid.value > 0 else { return nil }
            let running = TapHAL.value(object, kAudioProcessPropertyIsRunningOutput, initial: UInt32(0))
            return AudioProcessInfo(objectID: object, pid: pid.value,
                                    bundleID: TapHAL.string(object, kAudioProcessPropertyBundleID).value,
                                    isRunningOutput: running.value != 0)
        }
    }
}

/// One app's volume, live: a muted-when-tapped process tap on the app's
/// processes, inside a private aggregate device whose output is the current
/// default output device, and an IO proc that copies the tap to the output
/// at the chosen gain.
///
/// Muted-when-tapped: CATapDescription.h says the app's audio is "sent to
/// the audio hardware until the tap is read by another audio client. For the
/// duration of the read activity on the tap no audio is sent". So when our IO
/// stops — teardown, a device change, a crash — the app should be heard
/// again at its own level (the crash case is inferred from that wording;
/// the spike's `--crash` run is there to confirm it). Both objects are
/// private to this process: AudioHardware.h says a private aggregate "is not
/// persistent across launches of the process that created it", and a
/// private tap is "only visible to the client process that created" it.
/// `stop()` destroys everything explicitly anyway, newest first.
@available(macOS 14.2, *)
final class ProcessTapSession {
    enum Step: String {
        case outputDevice = "read the output device"
        case createTap = "create the process tap"
        case tapUID = "read the tap's ID"
        case createAggregate = "create the aggregate device"
        case layout = "read the aggregate's streams"
        case createIOProc = "create the IO proc"
        case streamUsage = "switch off hardware inputs"
        case start = "start IO"
    }

    struct Failure: Error, Equatable {
        let step: Step
        let status: OSStatus
        var message: String { "Couldn't \(step.rawValue) (error \(AppVolumeModel.describe(status: status)))" }
    }

    let processObjectIDs: Set<AudioObjectID>
    let outputDevice: AudioDeviceID
    let startedAt = Date()

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private var state: UnsafeMutablePointer<TapRenderState>?
    private var isRunning = false

    private init(processObjectIDs: Set<AudioObjectID>, outputDevice: AudioDeviceID) {
        self.processObjectIDs = processObjectIDs
        self.outputDevice = outputDevice
    }

    deinit { stop() }

    /// Builds and starts a session, or tears down whatever part of it was
    /// built and reports the step that failed.
    static func start(processes: Set<AudioObjectID>, outputDevice: AudioDeviceID,
                      gain: Float) -> Result<ProcessTapSession, Failure> {
        let session = ProcessTapSession(processObjectIDs: processes, outputDevice: outputDevice)
        do {
            try session.build(gain: gain)
            return .success(session)
        } catch let failure as Failure {
            session.stop()
            return .failure(failure)
        } catch {
            session.stop()
            return .failure(Failure(step: .start, status: -1))
        }
    }

    private func build(gain: Float) throws {
        // 1. The device the sound should come out of.
        let uid = TapHAL.string(outputDevice, kAudioDevicePropertyDeviceUID)
        guard uid.status == noErr, let outputUID = uid.value else {
            throw Failure(step: .outputDevice, status: uid.status)
        }

        // 2. The tap: a stereo mix of the app's processes, which silences
        //    them on the speakers for as long as we read it.
        let description = CATapDescription(stereoMixdownOfProcesses: processObjectIDs.sorted())
        description.uuid = UUID()
        description.name = "MaxCandela App Volume"
        description.isPrivate = true
        description.muteBehavior = .mutedWhenTapped
        var tap = AudioObjectID(kAudioObjectUnknown)
        var status = AudioHardwareCreateProcessTap(description, &tap)
        guard status == noErr, tap != kAudioObjectUnknown else { throw Failure(step: .createTap, status: status) }
        tapID = tap

        let tapUID = TapHAL.string(tapID, kAudioTapPropertyUID)
        guard tapUID.status == noErr, let tapUIDString = tapUID.value else {
            throw Failure(step: .tapUID, status: tapUID.status)
        }

        // 3. A private aggregate: the output device (which sets the clock)
        //    plus the tap as an extra input. Drift compensation on the tap,
        //    since the app may be playing to another device's clock.
        let composition: [String: Any] = [
            kAudioAggregateDeviceNameKey: "MaxCandela App Volume",
            // The prefix keeps it out of the Sound tool's device list.
            kAudioAggregateDeviceUIDKey: AudioDevices.appVolumeUIDPrefix + UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: 1,
            kAudioAggregateDeviceIsStackedKey: 0,
            kAudioAggregateDeviceTapAutoStartKey: 1,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[kAudioSubTapUIDKey: tapUIDString,
                                               kAudioSubTapDriftCompensationKey: 1]],
        ]
        var aggregate = AudioObjectID(kAudioObjectUnknown)
        status = AudioHardwareCreateAggregateDevice(composition as CFDictionary, &aggregate)
        guard status == noErr, aggregate != kAudioObjectUnknown else {
            throw Failure(step: .createAggregate, status: status)
        }
        aggregateID = aggregate

        // 4. Where the tap and the speakers sit in the IO proc's buffers.
        let inputFormats = TapHAL.streamFormats(aggregateID, scope: kAudioObjectPropertyScopeInput)
        let outputFormats = TapHAL.streamFormats(aggregateID, scope: kAudioObjectPropertyScopeOutput)
        let inputStreams = inputFormats.count
        let deviceInputs = TapHAL.streamCount(outputDevice, scope: kAudioObjectPropertyScopeInput)
        guard let tapIndex = AppVolumeModel.tapStreamIndex(aggregateInputStreams: inputStreams,
                                                           deviceInputStreams: deviceInputs),
              AppVolumeModel.isFloat32PCM(inputFormats[tapIndex]),
              !outputFormats.isEmpty, outputFormats.allSatisfy(AppVolumeModel.isFloat32PCM),
              let routing = AppVolumeModel.stereoLocations(
                preferred: TapHAL.preferredStereo(outputDevice),
                streamChannelCounts: TapHAL.streamChannelCounts(aggregateID, scope: kAudioObjectPropertyScopeOutput))
        else { throw Failure(step: .layout, status: kAudioHardwareUnsupportedOperationError) }

        let rate = TapHAL.value(aggregateID, kAudioDevicePropertyNominalSampleRate, initial: Float64(48_000)).value
        let state = UnsafeMutablePointer<TapRenderState>.allocate(capacity: 1)
        state.initialize(to: TapRenderState(
            gain: gain,
            smoothing: AppVolumeMath.smoothingCoefficient(seconds: AppVolumeMath.gainSmoothingSeconds, sampleRate: rate),
            release: AppVolumeMath.releaseCoefficient(seconds: AppVolumeMath.limiterReleaseSeconds, sampleRate: rate),
            tapBufferIndex: tapIndex, left: routing.left, right: routing.right))
        self.state = state

        // 5. The IO proc.
        var proc: AudioDeviceIOProcID?
        status = AudioDeviceCreateIOProcID(aggregateID, AppVolumeDSP.ioProc, UnsafeMutableRawPointer(state), &proc)
        guard status == noErr, let proc else { throw Failure(step: .createIOProc, status: status) }
        procID = proc

        // 6. Never run the output device's own inputs. If that can't be
        //    guaranteed on a device that has some, don't start at all.
        if inputStreams > 1 {
            status = setInputStreamUsage(AppVolumeModel.inputStreamUsage(inputStreams: inputStreams, tapIndex: tapIndex),
                                         proc: proc)
            guard status == noErr else { throw Failure(step: .streamUsage, status: status) }
        }

        // 7. Go. The first start ever is what shows the "System Audio
        //    Recording" permission prompt.
        status = AudioDeviceStart(aggregateID, proc)
        guard status == noErr else { throw Failure(step: .start, status: status) }
        isRunning = true
    }

    /// `AudioHardwareIOProcStreamUsage` is variable-length:
    /// `{ void *mIOProc; UInt32 mNumberStreams; UInt32 mStreamIsOn[n]; }`.
    private func setInputStreamUsage(_ flags: [UInt32], proc: AudioDeviceIOProcID) -> OSStatus {
        let flagsOffset = MemoryLayout<UnsafeMutableRawPointer>.size + MemoryLayout<UInt32>.size
        let byteCount = flagsOffset + flags.count * MemoryLayout<UInt32>.size
        let raw = UnsafeMutableRawPointer.allocate(byteCount: byteCount,
                                                   alignment: MemoryLayout<UnsafeMutableRawPointer>.alignment)
        defer { raw.deallocate() }
        raw.storeBytes(of: unsafeBitCast(proc, to: UnsafeMutableRawPointer.self), as: UnsafeMutableRawPointer.self)
        raw.storeBytes(of: UInt32(flags.count), toByteOffset: MemoryLayout<UnsafeMutableRawPointer>.size, as: UInt32.self)
        for (index, flag) in flags.enumerated() {
            raw.storeBytes(of: flag, toByteOffset: flagsOffset + index * MemoryLayout<UInt32>.size, as: UInt32.self)
        }
        var addr = TapHAL.address(kAudioDevicePropertyIOProcStreamUsage, scope: kAudioObjectPropertyScopeInput)
        return AudioObjectSetPropertyData(aggregateID, &addr, 0, nil, UInt32(byteCount), raw)
    }

    /// Amplitude multiplier, 0 = muted. Takes ~10 ms to reach the speakers.
    func setGain(_ gain: Float) {
        guard let state else { return }
        state.pointee.targetGain = gain     // the one cross-thread store: one aligned 32-bit word
    }

    /// Cycles run, and cycles in which the tap delivered any sound.
    var counters: (callbacks: UInt32, audible: UInt32) {
        guard let state else { return (0, 0) }
        return (state.pointee.callbacks, state.pointee.audibleCallbacks)
    }

    /// Stop IO and destroy everything, newest first. Safe to call twice.
    func stop() {
        if let procID {
            if isRunning { AudioDeviceStop(aggregateID, procID) }
            AudioDeviceDestroyIOProcID(aggregateID, procID)
        }
        if aggregateID != kAudioObjectUnknown { AudioHardwareDestroyAggregateDevice(aggregateID) }
        if tapID != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(tapID) }
        procID = nil
        aggregateID = AudioObjectID(kAudioObjectUnknown)
        tapID = AudioObjectID(kAudioObjectUnknown)
        isRunning = false
        if let state {
            self.state = nil
            // The IO proc is destroyed and its device gone, so nothing can be
            // reading this. Freed a beat later all the same: the HAL headers
            // don't promise that a cycle already in flight on the IO thread
            // has finished when these calls return, and a late free costs a
            // few dozen bytes for half a second.
            let address = UInt(bitPattern: state)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard let state = UnsafeMutablePointer<TapRenderState>(bitPattern: address) else { return }
                state.deinitialize(count: 1)
                state.deallocate()
            }
        }
    }
}
