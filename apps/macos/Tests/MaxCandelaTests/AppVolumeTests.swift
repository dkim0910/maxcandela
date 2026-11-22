import CoreAudio
import XCTest
@testable import MaxCandela

/// App Volume's pure logic: the gain curve, the limiter, the render loop run
/// on plain arrays, the process grouping, the tap diffing and the buffer
/// layout. Nothing here creates a tap or touches the audio hardware.
final class AppVolumeTests: XCTestCase {

    // MARK: - Gain curve and dB

    func testGainCurveIsSquaredPercent() {
        XCTAssertEqual(AppVolumeMath.gain(percent: 0), 0)
        XCTAssertEqual(AppVolumeMath.gain(percent: 50), 0.25, accuracy: 1e-6)
        XCTAssertEqual(AppVolumeMath.gain(percent: 100), 1)
        XCTAssertEqual(AppVolumeMath.gain(percent: 200), 4, accuracy: 1e-6)
        // Out of range clamps rather than running away.
        XCTAssertEqual(AppVolumeMath.gain(percent: 500), 4, accuracy: 1e-6)
        XCTAssertEqual(AppVolumeMath.gain(percent: -10), 0)
        // Monotonic across the slider.
        var last: Float = -1
        for percent in stride(from: 0.0, through: 200, by: 1) {
            let gain = AppVolumeMath.gain(percent: percent)
            XCTAssertGreaterThan(gain, last)
            last = gain
        }
    }

    func testGainAndPercentRoundTrip() {
        for percent in [0.0, 12, 50, 99, 100, 137, 200] {
            XCTAssertEqual(AppVolumeMath.percent(gain: AppVolumeMath.gain(percent: percent)), percent, accuracy: 1e-3)
        }
    }

    func testDecibelMapping() {
        XCTAssertEqual(AppVolumeMath.decibels(percent: 100), 0, accuracy: 1e-9)
        XCTAssertEqual(AppVolumeMath.decibels(percent: 200), 12.041, accuracy: 1e-3)
        XCTAssertEqual(AppVolumeMath.decibels(percent: 50), -12.041, accuracy: 1e-3)
        XCTAssertEqual(AppVolumeMath.decibels(percent: 0), -.infinity)
        XCTAssertEqual(AppVolumeMath.percent(decibels: 0), 100, accuracy: 1e-9)
        XCTAssertEqual(AppVolumeMath.percent(decibels: AppVolumeMath.decibels(percent: 163)), 163, accuracy: 1e-9)
        // The dB figure is the gain's: 20·log10(gain).
        let gain = Double(AppVolumeMath.gain(percent: 150))
        XCTAssertEqual(AppVolumeMath.decibels(percent: 150), 20 * log10(gain), accuracy: 1e-4)
    }

    func testSnappingHoldsOneHundredAndClamps() {
        XCTAssertEqual(AppVolumeMath.snapped(96), 100)
        XCTAssertEqual(AppVolumeMath.snapped(104), 100)
        XCTAssertEqual(AppVolumeMath.snapped(95.4), 95)
        XCTAssertEqual(AppVolumeMath.snapped(104.6), 105)
        XCTAssertEqual(AppVolumeMath.snapped(150.4), 150)
        XCTAssertEqual(AppVolumeMath.snapped(-3), 0)
        XCTAssertEqual(AppVolumeMath.snapped(250), 200)
        XCTAssertEqual(AppVolumeMath.snapped(.nan), 100)
    }

    func testOnlyAnUntouchedAppGoesWithoutATap() {
        XCTAssertFalse(AppVolumeMath.needsTap(percent: 100, muted: false))
        XCTAssertTrue(AppVolumeMath.needsTap(percent: 100, muted: true))
        XCTAssertTrue(AppVolumeMath.needsTap(percent: 99, muted: false))
        XCTAssertTrue(AppVolumeMath.needsTap(percent: 0, muted: false))
        XCTAssertEqual(AppVolumeMath.describe(percent: 150, muted: false), "150%")
        XCTAssertEqual(AppVolumeMath.describe(percent: 150, muted: true), "Muted")
        XCTAssertEqual(AppVolumeMath.describe(percent: 0, muted: false), "0%")
    }

    // MARK: - Limiter

    func testSoftKneeIsIdentityBelowThresholdAndNeverPassesCeiling() {
        let threshold = AppVolumeMath.limiterThreshold
        let ceiling = AppVolumeMath.limiterCeiling
        XCTAssertEqual(AppVolumeMath.softKnee(0.3), 0.3)
        XCTAssertEqual(AppVolumeMath.softKnee(threshold), threshold)
        XCTAssertEqual(AppVolumeMath.limiterGain(peak: 0.5), 1)
        // Continuous where the knee starts.
        XCTAssertEqual(AppVolumeMath.softKnee(threshold + 1e-4), threshold + 1e-4, accuracy: 1e-5)
        // In Float, tanh saturates to exactly 1 for large arguments, so the
        // curve can *reach* the ceiling; it can't pass it beyond rounding.
        let tolerance: Float = 1e-6
        var last: Float = 0
        for step in 1...400 {
            let x = Float(step) * 0.02      // up to 8× full scale
            let y = AppVolumeMath.softKnee(x)
            XCTAssertLessThanOrEqual(y, ceiling + tolerance)
            XCTAssertGreaterThanOrEqual(y, last, "the curve must never fold back")
            XCTAssertLessThanOrEqual(AppVolumeMath.limiterGain(peak: x), 1)
            last = y
        }
        XCTAssertLessThanOrEqual(AppVolumeMath.softKnee(1_000_000), ceiling + tolerance)
        XCTAssertLessThan(ceiling + tolerance, 1, "the ceiling sits below full scale")
        XCTAssertEqual(AppVolumeMath.limiterGain(peak: .infinity), 0)
    }

    func testCoefficients() {
        let smoothing = AppVolumeMath.smoothingCoefficient(seconds: 0.01, sampleRate: 48_000)
        XCTAssertGreaterThan(smoothing, 0)
        XCTAssertLessThan(smoothing, 0.01)
        XCTAssertEqual(AppVolumeMath.smoothingCoefficient(seconds: 0, sampleRate: 48_000), 1)
        let release = AppVolumeMath.releaseCoefficient(seconds: 0.15, sampleRate: 48_000)
        XCTAssertGreaterThan(release, 0.999)
        XCTAssertLessThan(release, 1)
        // After one time constant, a one-pole step covers 1 − 1/e of the way.
        var value: Float = 0
        for _ in 0..<480 { value += (1 - value) * smoothing }
        XCTAssertEqual(value, 1 - exp(-1), accuracy: 1e-3)
    }

    // MARK: - Render loop

    private func makeState(gain: Float, current: Float? = nil, right: (Int, Int)? = (0, 1)) -> UnsafeMutablePointer<TapRenderState> {
        let state = UnsafeMutablePointer<TapRenderState>.allocate(capacity: 1)
        state.initialize(to: TapRenderState(
            gain: gain,
            smoothing: AppVolumeMath.smoothingCoefficient(seconds: AppVolumeMath.gainSmoothingSeconds, sampleRate: 48_000),
            release: AppVolumeMath.releaseCoefficient(seconds: AppVolumeMath.limiterReleaseSeconds, sampleRate: 48_000),
            tapBufferIndex: 0, left: (0, 0), right: right.map { (buffer: $0.0, channel: $0.1) }))
        if let current { state.pointee.currentGain = current }
        return state
    }

    /// Runs `process` over an interleaved stereo signal, in 512-frame cycles
    /// like the HAL, and returns the interleaved stereo output.
    private func run(_ input: [Float], state: UnsafeMutablePointer<TapRenderState>) -> [Float] {
        var output = [Float](repeating: 0, count: input.count)
        let frames = input.count / 2
        input.withUnsafeBufferPointer { inBuffer in
            output.withUnsafeMutableBufferPointer { outBuffer in
                var start = 0
                while start < frames {
                    let count = min(512, frames - start)
                    AppVolumeDSP.process(input: inBuffer.baseAddress! + start * 2, inputChannels: 2, frames: count,
                                         left: outBuffer.baseAddress! + start * 2, leftStride: 2,
                                         right: outBuffer.baseAddress! + start * 2 + 1, rightStride: 2,
                                         state: state)
                    start += count
                }
            }
        }
        return output
    }

    private func sine(frames: Int, amplitude: Float, frequency: Float = 997) -> [Float] {
        (0..<frames).flatMap { frame -> [Float] in
            let value = amplitude * sin(2 * .pi * frequency * Float(frame) / 48_000)
            return [value, value]
        }
    }

    func testUnityGainIsBitTransparent() {
        let state = makeState(gain: 1)
        defer { state.deallocate() }
        let input = sine(frames: 4_800, amplitude: 1.0)    // full scale: no limiter at 100%
        XCTAssertEqual(run(input, state: state), input)
    }

    func testAttenuationIsExactAndNeverLimited() {
        let state = makeState(gain: 0.25)
        defer { state.deallocate() }
        let input = sine(frames: 2_000, amplitude: 1.0)
        let output = run(input, state: state)
        for (a, b) in zip(input, output) { XCTAssertEqual(b, a * 0.25, accuracy: 1e-7) }
        XCTAssertEqual(state.pointee.limiterGain, 1)
    }

    func testBoostNeverExceedsTheCeiling() {
        // +12 dB on a full-scale signal: four times over full scale before
        // the limiter.
        let limit = AppVolumeMath.limiterCeiling + 1e-6     // see the soft-knee test
        let state = makeState(gain: 4)
        defer { state.deallocate() }
        let output = run(sine(frames: 48_000, amplitude: 1.0), state: state)
        let peak = output.map(abs).max() ?? 0
        XCTAssertLessThanOrEqual(peak, limit)
        XCTAssertGreaterThan(peak, AppVolumeMath.limiterThreshold, "a boost should still be louder")
        // Full-scale spikes out of silence, the hardest case for a limiter
        // with no look-ahead.
        var clicks = [Float](repeating: 0, count: 2 * 4_800)
        for frame in stride(from: 0, to: 4_800, by: 600) {
            clicks[frame * 2] = 1
            clicks[frame * 2 + 1] = -1
        }
        let clickState = makeState(gain: 4)
        defer { clickState.deallocate() }
        XCTAssertLessThanOrEqual(run(clicks, state: clickState).map(abs).max() ?? 0, limit)
    }

    func testQuietSignalsAreBoostedUntouchedByTheLimiter() {
        let state = makeState(gain: 4)
        defer { state.deallocate() }
        let input = sine(frames: 4_800, amplitude: 0.1)    // 0.4 after gain: under the knee
        let output = run(input, state: state)
        for (a, b) in zip(input, output) { XCTAssertEqual(b, a * 4, accuracy: 1e-6) }
    }

    func testGainChangesGlideInsteadOfJumping() {
        let state = makeState(gain: 1)
        defer { state.deallocate() }
        state.pointee.targetGain = 0     // mute, as the main thread would
        let input = [Float](repeating: 0.5, count: 2 * 4_800)
        let output = run(input, state: state)
        XCTAssertGreaterThan(output[0], 0.49, "the first sample after a change is not a step")
        XCTAssertLessThan(output[output.count - 1], 1e-4, "muted within 100 ms")
        for frame in 1..<(output.count / 2) {
            XCTAssertLessThanOrEqual(output[frame * 2], output[(frame - 1) * 2] + 1e-7)
        }
    }

    func testMonoOutputGetsTheMix() {
        let state = makeState(gain: 1, right: nil)
        defer { state.deallocate() }
        let input: [Float] = [0.2, 0.4, -0.6, 0.2]
        var output: [Float] = [9, 9]
        input.withUnsafeBufferPointer { inBuffer in
            output.withUnsafeMutableBufferPointer { outBuffer in
                AppVolumeDSP.process(input: inBuffer.baseAddress!, inputChannels: 2, frames: 2,
                                     left: outBuffer.baseAddress!, leftStride: 1, right: nil, rightStride: 1,
                                     state: state)
            }
        }
        XCTAssertEqual(output[0], 0.3, accuracy: 1e-7)
        XCTAssertEqual(output[1], -0.2, accuracy: 1e-7)
    }

    /// The whole IO-proc path: an aggregate whose input is a disabled
    /// headset microphone (nil data) followed by the tap, and whose output
    /// device has four channels with its stereo pair on 3 and 4.
    func testRenderFindsTheTapAndWritesOnlyTheChosenChannels() {
        let frames = 4
        let input = AudioBufferList.allocate(maximumBuffers: 2)
        let output = AudioBufferList.allocate(maximumBuffers: 1)
        let tapSamples = UnsafeMutablePointer<Float>.allocate(capacity: frames * 2)
        let outSamples = UnsafeMutablePointer<Float>.allocate(capacity: frames * 4)
        defer {
            free(input.unsafeMutablePointer); free(output.unsafeMutablePointer)
            tapSamples.deallocate(); outSamples.deallocate()
        }
        for index in 0..<(frames * 2) { tapSamples[index] = index % 2 == 0 ? 0.25 : -0.5 }
        for index in 0..<(frames * 4) { outSamples[index] = 7 }        // stale data must be cleared
        input[0] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(frames * 4), mData: nil)
        input[1] = AudioBuffer(mNumberChannels: 2, mDataByteSize: UInt32(frames * 2 * 4), mData: tapSamples)
        output[0] = AudioBuffer(mNumberChannels: 4, mDataByteSize: UInt32(frames * 4 * 4), mData: outSamples)

        guard let routing = AppVolumeModel.stereoLocations(preferred: (3, 4), streamChannelCounts: [4]) else {
            return XCTFail("no routing")
        }
        let state = UnsafeMutablePointer<TapRenderState>.allocate(capacity: 1)
        defer { state.deallocate() }
        state.initialize(to: TapRenderState(gain: 1, smoothing: 1, release: 0, tapBufferIndex: 1,
                                            left: routing.left, right: routing.right))

        AppVolumeDSP.render(input: input.unsafePointer, output: output.unsafeMutablePointer, state: state)

        for frame in 0..<frames {
            XCTAssertEqual(outSamples[frame * 4 + 0], 0)
            XCTAssertEqual(outSamples[frame * 4 + 1], 0)
            XCTAssertEqual(outSamples[frame * 4 + 2], 0.25)
            XCTAssertEqual(outSamples[frame * 4 + 3], -0.5)
        }
        XCTAssertEqual(state.pointee.callbacks, 1)
        XCTAssertEqual(state.pointee.audibleCallbacks, 1)

        // A silent tap counts as a cycle but not as an audible one — the
        // signal the menu uses to suggest checking the permission.
        for index in 0..<(frames * 2) { tapSamples[index] = 0 }
        AppVolumeDSP.render(input: input.unsafePointer, output: output.unsafeMutablePointer, state: state)
        XCTAssertEqual(state.pointee.callbacks, 2)
        XCTAssertEqual(state.pointee.audibleCallbacks, 1)

        // A tap index that doesn't exist leaves silence, not garbage.
        state.pointee.tapBufferIndex = 5
        for index in 0..<(frames * 4) { outSamples[index] = 7 }
        AppVolumeDSP.render(input: input.unsafePointer, output: output.unsafeMutablePointer, state: state)
        XCTAssertTrue((0..<(frames * 4)).allSatisfy { outSamples[$0] == 0 })
    }

    // MARK: - Processes → apps

    func testHelpersAreFiledUnderTheirApp() {
        let apps: Set<String> = ["com.google.Chrome", "com.spotify.client", "com.a", "com.a.b"]
        XCTAssertEqual(AppVolumeModel.appKey(bundleID: "com.google.Chrome.helper", pid: 1, appBundleIDs: apps),
                       "com.google.Chrome")
        XCTAssertEqual(AppVolumeModel.appKey(bundleID: "com.spotify.client", pid: 1, appBundleIDs: apps),
                       "com.spotify.client")
        // Longest dotted prefix wins.
        XCTAssertEqual(AppVolumeModel.appKey(bundleID: "com.a.b.helper", pid: 1, appBundleIDs: apps), "com.a.b")
        // A prefix that is not at a dot boundary is a different app.
        XCTAssertEqual(AppVolumeModel.appKey(bundleID: "com.google.ChromeBeta", pid: 1, appBundleIDs: apps),
                       "com.google.ChromeBeta")
        // No running parent: stands as its own row.
        XCTAssertEqual(AppVolumeModel.appKey(bundleID: "com.apple.WebKit.GPU", pid: 1, appBundleIDs: apps),
                       "com.apple.WebKit.GPU")
        XCTAssertEqual(AppVolumeModel.appKey(bundleID: nil, pid: 42, appBundleIDs: apps), "pid:42")
        XCTAssertEqual(AppVolumeModel.appKey(bundleID: "", pid: 42, appBundleIDs: apps), "pid:42")
    }

    func testGroupingMergesHelpersAndLeavesUsOut() {
        let processes = [
            AudioProcessInfo(objectID: 90, pid: 900, bundleID: "com.google.Chrome.helper", isRunningOutput: true),
            AudioProcessInfo(objectID: 80, pid: 800, bundleID: "com.google.Chrome", isRunningOutput: false),
            AudioProcessInfo(objectID: 70, pid: 700, bundleID: "com.spotify.client", isRunningOutput: false),
            AudioProcessInfo(objectID: 60, pid: 600, bundleID: "com.maxcandela.MaxCandela", isRunningOutput: true),
        ]
        let apps = AppVolumeModel.group(processes, appBundleIDs: ["com.google.Chrome", "com.spotify.client"],
                                        excludingPID: 600)
        XCTAssertEqual(apps, [
            AudioApp(key: "com.google.Chrome", processObjectIDs: [80, 90], pids: [800, 900], isPlaying: true),
            AudioApp(key: "com.spotify.client", processObjectIDs: [70], pids: [700], isPlaying: false),
        ])
        // Playing apps are listed; a quiet one only once it has a setting.
        XCTAssertEqual(AppVolumeModel.visibleApps(apps, adjusted: []).map(\.key), ["com.google.Chrome"])
        XCTAssertEqual(AppVolumeModel.visibleApps(apps, adjusted: ["com.spotify.client"]).map(\.key),
                       ["com.google.Chrome", "com.spotify.client"])
    }

    // MARK: - Tap diffing

    func testPlanStartsStopsAndRebuilds() {
        let plan = AppVolumeModel.plan(
            wanted: ["new": [1], "same": [2], "helper": [3, 4], "quit": [], "gone": [9]],
            running: ["same": [2], "helper": [3], "quit": [5], "dropped": [6]])
        XCTAssertEqual(plan.start, ["gone", "new"])
        XCTAssertEqual(plan.rebuild, ["helper"])
        XCTAssertEqual(plan.stop, ["dropped", "quit"])
    }

    func testPlanIsEmptyWhenNothingChanged() {
        XCTAssertTrue(AppVolumeModel.plan(wanted: ["a": [1, 2]], running: ["a": [2, 1]]).isEmpty)
        XCTAssertTrue(AppVolumeModel.plan(wanted: [:], running: [:]).isEmpty)
        // An app with a setting that isn't running yet: nothing to do until it starts.
        XCTAssertTrue(AppVolumeModel.plan(wanted: ["later": []], running: [:]).isEmpty)
    }

    // MARK: - Buffer layout

    func testTapIsTheOneStreamAfterTheDevicesInputs() {
        XCTAssertEqual(AppVolumeModel.tapStreamIndex(aggregateInputStreams: 1, deviceInputStreams: 0), 0)
        XCTAssertEqual(AppVolumeModel.tapStreamIndex(aggregateInputStreams: 3, deviceInputStreams: 2), 2)
        // Any other layout is refused rather than guessed at.
        XCTAssertNil(AppVolumeModel.tapStreamIndex(aggregateInputStreams: 2, deviceInputStreams: 0))
        XCTAssertNil(AppVolumeModel.tapStreamIndex(aggregateInputStreams: 0, deviceInputStreams: 0))
        XCTAssertNil(AppVolumeModel.tapStreamIndex(aggregateInputStreams: 1, deviceInputStreams: 1))
    }

    func testOnlyTheTapStreamIsSwitchedOn() {
        XCTAssertEqual(AppVolumeModel.inputStreamUsage(inputStreams: 3, tapIndex: 2), [0, 0, 1])
        XCTAssertEqual(AppVolumeModel.inputStreamUsage(inputStreams: 1, tapIndex: 0), [1])
        XCTAssertEqual(AppVolumeModel.inputStreamUsage(inputStreams: 0, tapIndex: 0), [])
    }

    func testChannelLocations() {
        XCTAssertEqual(AppVolumeModel.channelLocation(0, streamChannelCounts: [2])?.buffer, 0)
        XCTAssertEqual(AppVolumeModel.channelLocation(1, streamChannelCounts: [2])?.channel, 1)
        let second = AppVolumeModel.channelLocation(1, streamChannelCounts: [1, 1])
        XCTAssertEqual(second?.buffer, 1)
        XCTAssertEqual(second?.channel, 0)
        XCTAssertNil(AppVolumeModel.channelLocation(2, streamChannelCounts: [2]))
        XCTAssertNil(AppVolumeModel.channelLocation(-1, streamChannelCounts: [2]))
    }

    func testStereoRoutingFollowsTheDevice() {
        // Built-in speakers: one stereo stream.
        let speakers = AppVolumeModel.stereoLocations(preferred: (1, 2), streamChannelCounts: [2])
        XCTAssertEqual(speakers?.left.buffer, 0)
        XCTAssertEqual(speakers?.left.channel, 0)
        XCTAssertEqual(speakers?.right?.channel, 1)
        // An interface whose monitors are on 3/4.
        let interface = AppVolumeModel.stereoLocations(preferred: (3, 4), streamChannelCounts: [8])
        XCTAssertEqual(interface?.left.channel, 2)
        XCTAssertEqual(interface?.right?.channel, 3)
        // Two mono streams.
        let split = AppVolumeModel.stereoLocations(preferred: nil, streamChannelCounts: [1, 1])
        XCTAssertEqual(split?.left.buffer, 0)
        XCTAssertEqual(split?.right?.buffer, 1)
        // A preferred pair that doesn't exist falls back to the first two.
        let bogus = AppVolumeModel.stereoLocations(preferred: (7, 8), streamChannelCounts: [2])
        XCTAssertEqual(bogus?.left.channel, 0)
        XCTAssertEqual(bogus?.right?.channel, 1)
        // Mono device: left only.
        let mono = AppVolumeModel.stereoLocations(preferred: (1, 2), streamChannelCounts: [1])
        XCTAssertEqual(mono?.left.channel, 0)
        XCTAssertNil(mono?.right)
        XCTAssertNil(AppVolumeModel.stereoLocations(preferred: (1, 2), streamChannelCounts: []))
    }

    func testOnlyFloat32IsAccepted() {
        var format = AudioStreamBasicDescription(
            mSampleRate: 48_000, mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 8, mFramesPerPacket: 1, mBytesPerFrame: 8,
            mChannelsPerFrame: 2, mBitsPerChannel: 32, mReserved: 0)
        XCTAssertTrue(AppVolumeModel.isFloat32PCM(format))
        format.mBitsPerChannel = 16
        format.mFormatFlags = kAudioFormatFlagIsSignedInteger
        XCTAssertFalse(AppVolumeModel.isFloat32PCM(format))
        format.mBitsPerChannel = 32
        format.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsBigEndian
        XCTAssertFalse(AppVolumeModel.isFloat32PCM(format))
    }

    func testOurAggregatesStayOutOfTheSoundMenu() {
        XCTAssertTrue(AudioDevices.isAppVolumeDevice(uid: AudioDevices.appVolumeUIDPrefix + UUID().uuidString))
        XCTAssertFalse(AudioDevices.isAppVolumeDevice(uid: "BuiltInSpeakerDevice"))
        XCTAssertFalse(AudioDevices.isAppVolumeDevice(uid: nil))
    }

    func testHALErrorsReadAsTheirFourCharCodes() {
        XCTAssertEqual(AppVolumeModel.describe(status: OSStatus(kAudioHardwareBadDeviceError)), "'!dev'")
        XCTAssertEqual(AppVolumeModel.describe(status: OSStatus(kAudioHardwareBadObjectError)), "'!obj'")
        XCTAssertEqual(AppVolumeModel.describe(status: -50), "-50")
        XCTAssertEqual(AppVolumeModel.describe(status: 0), "0")
    }
}
