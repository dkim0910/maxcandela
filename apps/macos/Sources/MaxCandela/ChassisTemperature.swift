import Foundation
import IOKit

/// The Mac's internal temperature in °C, read from the battery pack's sensor.
///
/// **Why this sensor.** The boost heats the *panel*, and a sandboxed app gets no
/// display thermometer: `AppleCLCD2` publishes only a static
/// `InitialPanelTemperature` (and a `PDCGlobalTemp` that reads 0), and the SMC
/// sensors that tools like Macs Fan Control use need a privileged helper the App
/// Store sandbox forbids — the same wall that makes fan control impossible here
/// (see CLAUDE.md). `AppleSmartBattery`'s `Temperature` is a plain IO-registry
/// property read: public API, no entitlement, verified readable inside a bundle
/// signed with our shipping sandbox entitlements.
///
/// **What it is and isn't.** It is a whole-chassis proxy that lags the panel by
/// minutes, not a panel probe. Callers must pair it with wide hysteresis so the
/// lag cannot make the boost oscillate, and must degrade gracefully when it
/// returns `nil` — a desktop Mac driving an XDR display has no battery at all.
enum ChassisTemperature {
    /// `AppleSmartBattery` reports temperature in hundredths of a degree
    /// Celsius (3003 → 30.03 °C).
    private static let unitsPerDegree = 100.0

    /// Anything outside this range is a misread or a unit change in a future
    /// macOS, not a real chassis reading — discard rather than act on it.
    private static let plausibleRange: ClosedRange<Double> = -20...100

    /// Current chassis temperature in °C, or nil when there is no readable
    /// sensor (desktop Macs) or the value fails the sanity check.
    static func current() -> Double? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                  IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        let raw = IORegistryEntryCreateCFProperty(service, "Temperature" as CFString,
                                                  kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? NSNumber
        guard let raw else { return nil }

        let celsius = raw.doubleValue / unitsPerDegree
        return plausibleRange.contains(celsius) ? celsius : nil
    }
}
