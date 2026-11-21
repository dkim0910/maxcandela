import CoreGraphics
import Foundation

/// Applies a per-display "lift" so SDR pixel values ride up into the EDR
/// headroom that the trigger window keeps engaged.
///
/// Two rules keep colors intact (learned on hardware — see CLAUDE.md):
///  1. Transfer tables hold *gamma-encoded* values. A desired luminance
///     multiply of S needs an encoded gain of S^(1/2.2); multiplying encoded
///     values by S directly over-drives luminance by S^2.2 and clips channels
///     into washed-out white.
///  2. Never replace the display's calibration: read the current ColorSync
///     tables once per display and scale *those*, preserving the per-channel
///     curve shapes. A plain ramp destroys calibration → dead colors.
///
/// Safety: CG gamma changes are per-process and auto-restore when the process
/// exits, so even a crash cannot leave the display stuck. `restoreAll()` gives
/// the explicit instant-restore path for disable/quit.
final class GammaController {
    private static let tableSize = 256

    private typealias RGBTables = (red: [Float], green: [Float], blue: [Float])

    /// Pristine calibration tables captured per display before our first lift.
    /// Re-reading after we've applied a lift would compound gains.
    private var baseTables: [CGDirectDisplayID: RGBTables] = [:]

    // MARK: - Pure math (unit-tested)

    /// Encoded-space gain that produces a luminance multiply of `scale` through
    /// a display transfer curve of the given gamma.
    static func encodedGain(forLuminanceScale scale: Float, gamma: Float = 2.2) -> Float {
        guard scale > 0 else { return 1 }
        return pow(scale, 1 / gamma)
    }

    /// Scale an existing calibration table so on-screen luminance multiplies by
    /// `luminanceScale`, preserving the curve's shape (and therefore color).
    static func liftTable(base: [Float], luminanceScale: Float) -> [Float] {
        let gain = encodedGain(forLuminanceScale: luminanceScale)
        return base.map { $0 * gain }
    }

    /// Linear-light channel gains for a warmth of 0 (neutral) … 1 (warmest).
    ///
    /// Red stays at 1 and the other two only ever come *down*, so warmth can
    /// never push a channel above what the luminance scale already put there —
    /// the "never exceed current headroom" clamp holds with no extra work. The
    /// end point (green ×0.72, blue ×0.42) is an incandescent-ish white chosen
    /// by eye-model, not measured; tune here if it reads too orange.
    static func warmthGains(_ warmth: Float) -> (red: Float, green: Float, blue: Float) {
        let w = max(0, min(1, warmth))
        return (1, 1 - 0.28 * w, 1 - 0.58 * w)
    }

    /// Lowest luminance Extra Dim may reach. A floor rather than zero: a
    /// screen dimmed to black cannot be used to undim itself.
    static let minimumDim: CGFloat = 0.2

    // MARK: - Display application

    /// Apply a luminance scale (lift above 1.0, dim below) and a warmth to one
    /// display. Returns true on success. The channel gains are linear-light
    /// like the scale, so they go through the same encoded-gain conversion.
    @discardableResult
    func apply(scale: CGFloat, warmth: CGFloat = 0, to displayID: CGDirectDisplayID) -> Bool {
        let base = cachedBase(for: displayID)
        let gains = Self.warmthGains(Float(warmth))
        let red = Self.liftTable(base: base.red, luminanceScale: Float(scale) * gains.red)
        let green = Self.liftTable(base: base.green, luminanceScale: Float(scale) * gains.green)
        let blue = Self.liftTable(base: base.blue, luminanceScale: Float(scale) * gains.blue)

        let tableResult = CGSetDisplayTransferByTable(
            displayID,
            UInt32(red.count),
            red, green, blue
        )
        if tableResult == .success {
            // No per-call logging: the fade animator applies at 30 Hz.
            return true
        }

        // Fallback: formula path. Loses per-channel calibration but functional.
        let formulaResult = CGSetDisplayTransferByFormula(
            displayID,
            0, Self.encodedGain(forLuminanceScale: Float(scale) * gains.red), 1,    // red   min/max/gamma
            0, Self.encodedGain(forLuminanceScale: Float(scale) * gains.green), 1,  // green
            0, Self.encodedGain(forLuminanceScale: Float(scale) * gains.blue), 1    // blue
        )
        if formulaResult == .success {
            return true
        }

        NSLog("MaxCandela: gamma lift failed on display %u (table: %d, formula: %d) — capture-and-remap fallback needed, see CLAUDE.md",
              displayID, tableResult.rawValue, formulaResult.rawValue)
        return false
    }

    /// Restore every display we may have touched to its ColorSync state.
    func restoreAll() {
        CGDisplayRestoreColorSyncSettings()
        baseTables.removeAll()   // safe to re-read pristine tables next time
        NSLog("MaxCandela: gamma restored to ColorSync defaults")
    }

    // MARK: - Base table capture

    /// The display's calibration tables from before our first lift. Falls back
    /// to an identity ramp if the tables can't be read.
    private func cachedBase(for displayID: CGDirectDisplayID) -> RGBTables {
        if let cached = baseTables[displayID] { return cached }

        var red = [Float](repeating: 0, count: Self.tableSize)
        var green = [Float](repeating: 0, count: Self.tableSize)
        var blue = [Float](repeating: 0, count: Self.tableSize)
        var sampleCount: UInt32 = 0
        let result = CGGetDisplayTransferByTable(
            displayID, UInt32(Self.tableSize),
            &red, &green, &blue, &sampleCount
        )

        let base: RGBTables
        if result == .success, sampleCount > 1 {
            let n = Int(sampleCount)
            base = (Array(red[0..<n]), Array(green[0..<n]), Array(blue[0..<n]))
        } else {
            NSLog("MaxCandela: could not read calibration tables for display %u; using identity ramp", displayID)
            let ramp = (0..<Self.tableSize).map { Float($0) / Float(Self.tableSize - 1) }
            base = (ramp, ramp, ramp)
        }
        baseTables[displayID] = base
        return base
    }
}
