import Foundation
import IOKit.ps

/// Whether the Mac is running from its battery, and a callback when that
/// changes. Public IOKit power-source API, no entitlement needed.
///
/// Exists for "Pause Boost on Battery": the boost drives the backlight well
/// past its normal ceiling, which is the single biggest drain it can add.
final class PowerMonitor {
    /// Fires on the main run loop whenever the power source report changes.
    /// That includes charge-percentage ticks, not only plug/unplug — callers
    /// must compare against their own last state.
    var onChange: (() -> Void)?

    private var runLoopSource: CFRunLoopSource?

    init() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            Unmanaged<PowerMonitor>.fromOpaque(context).takeUnretainedValue().onChange?()
        }, context)?.takeRetainedValue()
        if let source {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = source
        }
    }

    deinit {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
    }

    /// True while the Mac draws from its internal battery. Desktop Macs and
    /// anything on mains (or a UPS) report false.
    var isOnBattery: Bool {
        #if DEBUG
        // MAXCANDELA_FORCE_BATTERY=1|0 fakes the power source so the pause
        // can be exercised without pulling the plug.
        if let forced = ProcessInfo.processInfo.environment["MAXCANDELA_FORCE_BATTERY"] {
            return forced == "1"
        }
        #endif
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(snapshot)?.takeUnretainedValue()
        else { return false }
        return Self.isBattery(providingSourceType: type as String)
    }

    /// Pure, unit-tested: only the internal battery counts. "UPS Power" is a
    /// desktop on a backup supply — not the case this feature is for.
    static func isBattery(providingSourceType type: String) -> Bool {
        type == kIOPMBatteryPowerKey
    }
}
