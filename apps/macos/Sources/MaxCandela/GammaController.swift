import CoreGraphics
import Foundation

/// Applies a per-display "lift" so SDR pixel values ride up into the EDR
/// headroom that the trigger window keeps engaged. Two experiments, tried in
/// order (real-hardware behavior decides which sticks — see CLAUDE.md):
///
///  A. `CGSetDisplayTransferByTable` with LUT values scaled above 1.0.
///     Verified by reading the table back; if the OS clamped it, fall through.
///  B. `CGSetDisplayTransferByFormula` with `max = scale`.
///
/// Safety: CG gamma changes are per-process and auto-restore when the process
/// exits, so even a crash cannot leave the display stuck. `restoreAll()` gives
/// the explicit instant-restore path for disable/quit.
final class GammaController {
    private static let tableSize = 256

    /// Pure LUT builder, split out for unit testing: a linear ramp scaled by
    /// `scale`. Values may exceed 1.0 — whether the OS honors that is exactly
    /// what experiment A probes.
    static func makeLiftTable(scale: Float, count: Int = tableSize) -> [Float] {
        precondition(count > 1, "LUT needs at least two entries")
        return (0..<count).map { Float($0) / Float(count - 1) * scale }
    }

    /// Apply a brightness lift to one display. Returns true if some lift was
    /// applied (even a clamped one — the OS may cap at 1.0).
    @discardableResult
    func applyLift(scale: CGFloat, to displayID: CGDirectDisplayID) -> Bool {
        let table = Self.makeLiftTable(scale: Float(scale))

        // Experiment A: table with values above 1.0.
        let tableResult = CGSetDisplayTransferByTable(
            displayID,
            UInt32(table.count),
            table, table, table
        )
        if tableResult == .success, !readBackClamped(displayID: displayID, expectedMax: Float(scale)) {
            NSLog("MaxCandela: gamma lift %.2f× applied via table on display %u", scale, displayID)
            return true
        }

        // Experiment B: formula with max = scale.
        let formulaResult = CGSetDisplayTransferByFormula(
            displayID,
            0, Float(scale), 1,   // red   min/max/gamma
            0, Float(scale), 1,   // green
            0, Float(scale), 1    // blue
        )
        if formulaResult == .success {
            NSLog("MaxCandela: gamma lift %.2f× applied via formula on display %u (table path clamped or failed: %d)",
                  scale, displayID, tableResult.rawValue)
            return true
        }

        NSLog("MaxCandela: gamma lift failed on display %u (table: %d, formula: %d) — capture-and-remap fallback needed, see CLAUDE.md",
              displayID, tableResult.rawValue, formulaResult.rawValue)
        return false
    }

    /// Restore every display we may have touched to its ColorSync state.
    func restoreAll() {
        CGDisplayRestoreColorSyncSettings()
        NSLog("MaxCandela: gamma restored to ColorSync defaults")
    }

    /// Reads the transfer table back and reports whether the OS clamped our
    /// above-1.0 values down to ≤1.0.
    private func readBackClamped(displayID: CGDirectDisplayID, expectedMax: Float) -> Bool {
        guard expectedMax > 1.0 else { return false }
        var red = [Float](repeating: 0, count: Self.tableSize)
        var green = [Float](repeating: 0, count: Self.tableSize)
        var blue = [Float](repeating: 0, count: Self.tableSize)
        var sampleCount: UInt32 = 0
        let result = CGGetDisplayTransferByTable(
            displayID, UInt32(Self.tableSize),
            &red, &green, &blue, &sampleCount
        )
        guard result == .success, sampleCount > 0 else {
            // Can't verify — assume not clamped rather than double-applying.
            return false
        }
        let maxValue = red.prefix(Int(sampleCount)).max() ?? 0
        // Allow a little slack for interpolation/rounding.
        return maxValue < expectedMax * 0.9
    }
}
