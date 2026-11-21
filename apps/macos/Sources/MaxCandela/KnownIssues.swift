import Foundation

/// Hardware on which macOS itself is known to break the boost.
///
/// **M5 Pro / M5 Max (reported, not verified by us — no affected Mac to test
/// on).** Apple Developer Forums thread 819331 (opened March 2026, Apple bug
/// FB22273730, still open at macOS 27.2.1): `CGSetDisplayTransferByTable`
/// returns success and reads back the values it was given, but the screen does
/// not change. Apple's DTS engineer reproduced it on an M5 Max. The plain M5
/// and M3 Max are reported unaffected.
///
/// Because the call *reports success*, `GammaController` cannot detect the
/// failure — the menu would show the boost on while nothing brightens. All we
/// can do is tell the user up front, once, without blocking the toggle (Apple
/// may fix it in any update, and then the boost simply works).
///
/// Keyed on the chip name rather than model identifiers: one string covers
/// both screen sizes and needs no table to keep current. Delete this file once
/// FB22273730 is fixed in a shipping macOS.
enum KnownIssues {
    /// e.g. "Apple M5 Pro". Empty if the sysctl is unreadable.
    static var chipName: String {
        var size = 0
        guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0, size > 0 else { return "" }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0) == 0 else { return "" }
        return String(cString: buffer)
    }

    /// Pure, unit-tested. Only the two chips the reports name — not "M5"
    /// (reported working) and not future chips we know nothing about.
    static func gammaLiftReportedBroken(chip: String) -> Bool {
        let name = chip.lowercased()
        return name.contains("m5 pro") || name.contains("m5 max")
    }

    static var gammaLiftReportedBroken: Bool {
        #if DEBUG
        // MAXCANDELA_FORCE_CHIP="Apple M5 Max" previews the notice on any Mac.
        if let forced = ProcessInfo.processInfo.environment["MAXCANDELA_FORCE_CHIP"] {
            return gammaLiftReportedBroken(chip: forced)
        }
        #endif
        return gammaLiftReportedBroken(chip: chipName)
    }
}
