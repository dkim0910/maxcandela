import AppKit
import CoreAudio

/// App Volume (Pro): a level for each app that is playing sound, from silent
/// to twice as loud (0–200%, +12 dB at the top), and a mute button — the
/// audio counterpart of the brightness boost.
///
/// How: an app moved off 100% gets a Core Audio *process tap* (macOS 14.2+,
/// public API, no audio driver). The tap takes the app's sound away from the
/// speakers and hands it to us; we play it to the default output at the
/// chosen gain, through a soft limiter above 100%. Back at 100%, the tap is
/// destroyed and the app plays directly again. See `ProcessTapSession`,
/// `AppVolumeEngine`, `AppVolumeDSP`.
///
/// Unlike the rest of the toolbox this tool needs a new entitlement and a
/// permission (the exception `MenuTool` asks to be stated here):
///  - `com.apple.security.device.audio-input` — the sandbox's audio-input
///    capability, which Apple's own process-tap sample is built with;
///  - `NSAudioCaptureUsageDescription` — shown in the "System Audio
///    Recording" prompt the first time a tap starts.
///
/// ⚠️ Not run during development: building and unit tests only, no tap was
/// ever created. Verify on hardware before it ships — the standalone
/// TapSpike tool runs the same recipe step by step and prints each
/// OSStatus, sandboxed or not.
final class AppVolumeTool: NSObject, MenuTool, NSMenuDelegate {
    let menuItem = NSMenuItem(title: "App Volume", action: nil, keyEquivalent: "")
    var onStatusChange: (() -> Void)?
    var isPro: Bool { true }
    /// Process taps arrived in macOS 14.2; before that the tool is not in
    /// the menu at all.
    var isSupported: Bool {
        if #available(macOS 14.2, *) { return true }
        return false
    }

    private let submenu = NSMenu()
    /// The `AppVolumeEngine`, created on first use. Stored untyped because a
    /// stored property cannot be `@available`.
    private var engineStorage: AnyObject?

    private static let privacyURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!

    override init() {
        super.init()
        submenu.delegate = self
        menuItem.submenu = submenu
        menuItem.symbol("slider.vertical.3")
        ProGate.shared.observe { [weak self] allowed in
            // Pro lapsed: every app back to its own level, no tap left behind.
            guard !allowed, #available(macOS 14.2, *) else { return }
            (self?.engineStorage as? AppVolumeEngine)?.resetAll()
        }
    }

    @available(macOS 14.2, *)
    private var engine: AppVolumeEngine {
        if let engine = engineStorage as? AppVolumeEngine { return engine }
        let engine = AppVolumeEngine()
        engineStorage = engine
        return engine
    }

    func menuWillOpen() { rebuild() }

    /// The submenu itself is opening — read the playing apps again, since
    /// the top-level menu may have been open for a while.
    func menuNeedsUpdate(_ menu: NSMenu) { rebuild() }

    func shutdown() {
        guard #available(macOS 14.2, *) else { return }
        (engineStorage as? AppVolumeEngine)?.shutdown()
    }

    private func rebuild() {
        // Locked, the row is hidden: don't touch Core Audio for nothing.
        guard ProGate.shared.isAllowed, #available(macOS 14.2, *) else { return }
        let engine = self.engine
        engine.retryFailed()
        engine.refreshApps()
        submenu.removeAllItems()

        let rows = AppVolumeModel.visibleApps(engine.apps, adjusted: Set(engine.settings.keys))
            .map { (app: $0, identity: AppIdentity.resolve($0)) }
            .sorted { $0.identity.name.localizedCaseInsensitiveCompare($1.identity.name) == .orderedAscending }

        if rows.isEmpty {
            submenu.addItem(note("No app is playing sound"))
        }
        for row in rows {
            let key = row.app.key
            let setting = engine.setting(for: key)
            let view = AppVolumeRowView(
                name: row.identity.name, image: row.identity.icon,
                percent: setting.percent, muted: setting.muted,
                onPercent: { [weak engine] percent in engine?.setPercent(percent, for: key) },
                onMute: { [weak engine] muted in engine?.setMuted(muted, for: key) })
            let item = NSMenuItem()
            item.view = view
            submenu.addItem(item)
        }

        submenu.addItem(.separator())
        let reset = NSMenuItem(title: "Reset All", action: #selector(resetAll), keyEquivalent: "")
        reset.target = self
        reset.isEnabled = engine.hasAdjustments
        submenu.addItem(reset.symbol("arrow.counterclockwise"))

        if engine.looksUnauthorised {
            submenu.addItem(.separator())
            submenu.addItem(note("Hearing nothing from an app you changed?"))
            let open = NSMenuItem(title: "Check System Audio Recording Permission…",
                                  action: #selector(openPrivacySettings), keyEquivalent: "")
            open.target = self
            submenu.addItem(open.symbol("lock.shield"))
        }
        if let failure = engine.lastFailure {
            submenu.addItem(.separator())
            submenu.addItem(note(failure))
        }
        submenu.addItem(.separator())
        submenu.addItem(note("Apps appear here while they play sound"))
    }

    private func note(_ text: String) -> NSMenuItem {
        let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func resetAll() {
        guard #available(macOS 14.2, *) else { return }
        (engineStorage as? AppVolumeEngine)?.resetAll()
    }

    @objc private func openPrivacySettings() {
        NSWorkspace.shared.open(Self.privacyURL)
    }
}

/// The name and icon to show for an `AudioApp`.
enum AppIdentity {
    static func resolve(_ app: AudioApp) -> (name: String, icon: NSImage?) {
        if !app.key.hasPrefix("pid:"),
           let running = NSRunningApplication.runningApplications(withBundleIdentifier: app.key).first {
            return (running.localizedName ?? app.key, running.icon)
        }
        for pid in app.pids {
            if let running = NSRunningApplication(processIdentifier: pid), let name = running.localizedName {
                return (name, running.icon)
            }
        }
        if let pid = app.pids.first, let name = processName(pid) { return (name, nil) }
        return (app.key, nil)
    }

    /// The executable's short name, for processes LaunchServices doesn't
    /// know (the same fallback Apple's process-tap sample uses).
    private static func processName(_ pid: pid_t) -> String? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 else { return nil }
        let name = withUnsafeBytes(of: info.kp_proc.p_comm) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
        return name.isEmpty ? nil : name
    }
}
