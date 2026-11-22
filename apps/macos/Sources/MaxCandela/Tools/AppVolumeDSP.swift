import CoreAudio
import Foundation

/// Everything the render callback touches, allocated once per tap before IO
/// starts and freed only after IO has stopped (`ProcessTapSession`).
///
/// Real-time rules: the IO thread may not allocate, lock, log or touch a
/// Swift object, so the callback gets a raw pointer to this plain struct and
/// nothing else. The one value two threads share is `targetGain`: the main
/// thread stores it, the IO thread loads it once per cycle. It is a single
/// naturally aligned 32-bit word, which arm64 and x86-64 load and store in
/// one indivisible access, so the IO thread sees either the old gain or the
/// new one, never a mix — and with a single value there is no ordering to
/// get wrong. (Swift 5.9 has no standard atomic type: `Synchronization`
/// needs Swift 6 and macOS 15, swift-atomics is a dependency.) Everything
/// else is written by exactly one side.
struct TapRenderState {
    /// Main thread → IO thread. Amplitude multiplier; 0 = muted.
    var targetGain: Float
    // IO thread only.
    var currentGain: Float
    var limiterGain: Float = 1
    // Fixed before IO starts. The limiter's constants are copied in here
    // (on the main thread) so the IO thread never touches a lazily
    // initialised static.
    var smoothing: Float
    var release: Float
    var limiterThreshold: Float = AppVolumeMath.limiterThreshold
    var limiterCeiling: Float = AppVolumeMath.limiterCeiling
    var tapBufferIndex: Int32
    var leftBuffer: Int32
    var leftChannel: Int32
    /// −1 when the device has one channel: left gets the mono mix.
    var rightBuffer: Int32
    var rightChannel: Int32
    // IO thread → main thread, diagnostics only (wrapping counters).
    var callbacks: UInt32 = 0
    /// Cycles in which the tap delivered at least one non-zero sample. A tap
    /// that runs but never delivers sound is how a refused "System Audio
    /// Recording" permission is expected to look — nothing in the API
    /// reports it directly.
    var audibleCallbacks: UInt32 = 0

    init(gain: Float, smoothing: Float, release: Float, tapBufferIndex: Int,
         left: (buffer: Int, channel: Int), right: (buffer: Int, channel: Int)?) {
        targetGain = gain
        currentGain = gain          // no fade-in from silence when a tap starts
        self.smoothing = smoothing
        self.release = release
        self.tapBufferIndex = Int32(tapBufferIndex)
        leftBuffer = Int32(left.buffer)
        leftChannel = Int32(left.channel)
        rightBuffer = Int32(right?.buffer ?? -1)
        rightChannel = Int32(right?.channel ?? 0)
    }
}

/// The audio itself: tap in, gain and limiter, device out.
enum AppVolumeDSP {

    /// The HAL IO proc. A C function pointer rather than an IO *block*, so
    /// there is no Swift closure context — and so no reference counting — on
    /// the IO thread; the client-data pointer is the session's
    /// `TapRenderState`.
    static let ioProc: AudioDeviceIOProc = { _, _, inputData, _, outputData, _, clientData in
        guard let clientData else { return noErr }
        AppVolumeDSP.render(input: inputData, output: outputData,
                            state: clientData.assumingMemoryBound(to: TapRenderState.self))
        return noErr
    }

    /// One IO cycle: silence every output buffer, then write the tap's audio
    /// to the chosen channels. Input buffers other than the tap (a headset's
    /// microphone, switched off via stream usage) arrive with nil data and
    /// are ignored.
    static func render(input: UnsafePointer<AudioBufferList>,
                       output: UnsafeMutablePointer<AudioBufferList>,
                       state: UnsafeMutablePointer<TapRenderState>) {
        let outputs = UnsafeMutableAudioBufferListPointer(output)
        var index = 0
        while index < outputs.count {
            if let data = outputs[index].mData { memset(data, 0, Int(outputs[index].mDataByteSize)) }
            index += 1
        }
        state.pointee.callbacks &+= 1

        let inputs = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        let tapIndex = Int(state.pointee.tapBufferIndex)
        guard tapIndex >= 0, tapIndex < inputs.count, let tapData = inputs[tapIndex].mData else { return }
        let tapChannels = max(1, Int(inputs[tapIndex].mNumberChannels))
        var frames = Int(inputs[tapIndex].mDataByteSize) / (MemoryLayout<Float>.size * tapChannels)

        let leftIndex = Int(state.pointee.leftBuffer)
        guard leftIndex >= 0, leftIndex < outputs.count, let leftData = outputs[leftIndex].mData else { return }
        let leftStride = max(1, Int(outputs[leftIndex].mNumberChannels))
        let leftChannel = Int(state.pointee.leftChannel)
        guard leftChannel < leftStride else { return }
        frames = min(frames, Int(outputs[leftIndex].mDataByteSize) / (MemoryLayout<Float>.size * leftStride))
        let left = leftData.assumingMemoryBound(to: Float.self) + leftChannel

        var right: UnsafeMutablePointer<Float>?
        var rightStride = 1
        let rightIndex = Int(state.pointee.rightBuffer)
        if rightIndex >= 0, rightIndex < outputs.count, let rightData = outputs[rightIndex].mData {
            rightStride = max(1, Int(outputs[rightIndex].mNumberChannels))
            let rightChannel = Int(state.pointee.rightChannel)
            if rightChannel < rightStride {
                frames = min(frames, Int(outputs[rightIndex].mDataByteSize) / (MemoryLayout<Float>.size * rightStride))
                right = rightData.assumingMemoryBound(to: Float.self) + rightChannel
            }
        }
        guard frames > 0 else { return }

        process(input: UnsafePointer(tapData.assumingMemoryBound(to: Float.self)), inputChannels: tapChannels,
                frames: frames, left: left, leftStride: leftStride,
                right: right, rightStride: rightStride, state: state)
    }

    /// Gain, then the limiter, per frame. The limiter is linked across both
    /// channels (one gain for the pair) so the stereo image does not wander,
    /// and engages only while the gain is above 1 — at or below 100% the
    /// app's samples pass through scaled and nothing else.
    ///
    /// Why the output can never exceed `AppVolumeMath.limiterCeiling` (−0.5
    /// dBFS, to within float rounding): the gain applied to a frame is never
    /// more than `limiterGain(peak:)` for that frame's peak (attack is
    /// instant; release only moves back towards what the current frame
    /// allows), and `softKnee` never goes above the ceiling.
    /// `AppVolumeTests` checks it at +12 dB on full-scale input.
    static func process(input: UnsafePointer<Float>, inputChannels: Int, frames: Int,
                        left: UnsafeMutablePointer<Float>, leftStride: Int,
                        right: UnsafeMutablePointer<Float>?, rightStride: Int,
                        state: UnsafeMutablePointer<TapRenderState>) {
        let target = state.pointee.targetGain
        let smoothing = state.pointee.smoothing
        let release = state.pointee.release
        let threshold = state.pointee.limiterThreshold
        let ceiling = state.pointee.limiterCeiling
        var gain = state.pointee.currentGain
        var reduction = state.pointee.limiterGain
        var heard = false

        var frame = 0
        while frame < frames {
            let base = frame * inputChannels
            let inL = input[base]
            let inR = inputChannels > 1 ? input[base + 1] : inL
            if inL != 0 || inR != 0 { heard = true }

            gain += (target - gain) * smoothing
            var l = inL * gain
            var r = inR * gain

            var required: Float = 1
            if gain > 1 {
                required = AppVolumeMath.limiterGain(peak: max(abs(l), abs(r)),
                                                     threshold: threshold, ceiling: ceiling)
            }
            reduction = required < reduction ? required : required + (reduction - required) * release
            l *= reduction
            r *= reduction

            if let right {
                left[frame * leftStride] = l
                right[frame * rightStride] = r
            } else {
                left[frame * leftStride] = 0.5 * (l + r)
            }
            frame += 1
        }

        state.pointee.currentGain = gain
        state.pointee.limiterGain = reduction
        if heard { state.pointee.audibleCallbacks &+= 1 }
    }
}
