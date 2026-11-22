import Foundation

/// The arithmetic behind App Volume, free of Core Audio so it is unit-tested
/// (`AppVolumeTests`).
///
/// Two scales are involved. **Percent** is what the slider shows, 0…200.
/// **Gain** is the amplitude multiplier applied to the app's samples. They are
/// not the same number on purpose — see `gain(percent:)`.
enum AppVolumeMath {
    static let maxPercent: Double = 200
    static let unityPercent: Double = 100
    /// Within this many points of 100% the slider lands on exactly 100%.
    /// 100% is the only setting with no tap at all, so it has to be easy to
    /// hit by hand.
    static let snapDistance: Double = 4

    // MARK: - Gain curve

    /// Amplitude = (percent / 100)². Loudness is heard roughly as amplitude
    /// to the power 0.6, so a squared taper makes equal slider steps sound
    /// roughly equal: 50% is −12 dB, 100% is untouched, 200% is +12 dB —
    /// about twice as loud. A linear taper would crowd almost all of the
    /// audible change into the bottom tenth of the slider.
    static func gain(percent: Double) -> Float {
        let p = max(0, min(maxPercent, percent)) / unityPercent
        return Float(p * p)
    }

    /// Inverse of `gain(percent:)`.
    static func percent(gain: Float) -> Double {
        unityPercent * Double(max(0, gain)).squareRoot()
    }

    /// The slider position as decibels relative to the app's own level:
    /// 20·log10(gain) = 40·log10(percent/100). −∞ at 0%.
    static func decibels(percent: Double) -> Double {
        guard percent > 0 else { return -.infinity }
        return 40 * log10(percent / unityPercent)
    }

    /// Inverse of `decibels(percent:)`.
    static func percent(decibels: Double) -> Double {
        unityPercent * pow(10, decibels / 40)
    }

    /// What a raw slider value becomes: clamped to 0…200, whole percent, and
    /// pulled onto 100% when close to it.
    static func snapped(_ percent: Double) -> Double {
        guard percent.isFinite else { return unityPercent }
        let clamped = max(0, min(maxPercent, percent))
        if abs(clamped - unityPercent) <= snapDistance { return unityPercent }
        return clamped.rounded()
    }

    /// An app needs a tap only when it is not playing exactly as it would
    /// without MaxCandela.
    static func needsTap(percent: Double, muted: Bool) -> Bool {
        muted || percent != unityPercent
    }

    /// The text on the right of a row.
    static func describe(percent: Double, muted: Bool) -> String {
        muted ? "Muted" : "\(Int(snapped(percent)))%"
    }

    // MARK: - Limiter

    /// Above 100% an app's loud passages would exceed full scale and clip.
    /// The limiter leaves everything below `limiterThreshold` alone and bends
    /// everything above it smoothly towards `limiterCeiling`, which it never
    /// passes: a soft knee rather than a wall.
    static let limiterThreshold: Float = 0.708   // −3 dBFS
    static let limiterCeiling: Float = 0.944     // −0.5 dBFS: headroom for inter-sample peaks

    /// The limiter's static curve: the level a peak of `peak` is allowed to
    /// come out at. Identity up to the threshold, then
    /// T + (C − T)·tanh((x − T)/(C − T)) — slope 1 where it joins (tanh′(0)
    /// = 1, so no kink), approaching C and never above it. (In Float, tanh
    /// rounds to exactly 1 for large arguments, so C itself can be reached;
    /// C is −0.5 dBFS, so that is still short of clipping.)
    ///
    /// The render thread passes `threshold` and `ceiling` from its own state:
    /// a static stored property is initialised lazily on first access, and
    /// that first access must not happen on the IO thread.
    static func softKnee(_ peak: Float, threshold: Float, ceiling: Float) -> Float {
        let x = abs(peak)
        guard x > threshold else { return x }
        let room = ceiling - threshold
        return threshold + room * tanh((x - threshold) / room)
    }

    /// The gain reduction (≤ 1) that brings `peak` onto the soft-knee curve.
    static func limiterGain(peak: Float, threshold: Float, ceiling: Float) -> Float {
        let x = abs(peak)
        guard x > threshold, x.isFinite else { return x.isFinite ? 1 : 0 }
        return softKnee(x, threshold: threshold, ceiling: ceiling) / x
    }

    static func softKnee(_ peak: Float) -> Float {
        softKnee(peak, threshold: limiterThreshold, ceiling: limiterCeiling)
    }

    static func limiterGain(peak: Float) -> Float {
        limiterGain(peak: peak, threshold: limiterThreshold, ceiling: limiterCeiling)
    }

    /// How long a slider change takes to reach the speakers (and a mute to
    /// fade): short enough to feel instant, long enough not to click.
    static let gainSmoothingSeconds: Double = 0.010
    /// How fast the limiter lets go after a peak. Attack is instantaneous —
    /// that is what guarantees nothing overshoots the ceiling.
    static let limiterReleaseSeconds: Double = 0.150

    /// Per-sample one-pole step towards a target: 1 − e^(−1/(τ·fs)).
    static func smoothingCoefficient(seconds: Double, sampleRate: Double) -> Float {
        guard seconds > 0, sampleRate > 0 else { return 1 }
        return Float(1 - exp(-1 / (seconds * sampleRate)))
    }

    /// Per-sample decay factor of the limiter's release: e^(−1/(τ·fs)).
    static func releaseCoefficient(seconds: Double, sampleRate: Double) -> Float {
        guard seconds > 0, sampleRate > 0 else { return 0 }
        return Float(exp(-1 / (seconds * sampleRate)))
    }
}
