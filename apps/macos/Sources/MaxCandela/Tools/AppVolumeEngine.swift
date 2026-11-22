import AppKit
import CoreAudio

/// App Volume's state and the taps that carry it out. Main thread only.
///
/// Settings live in memory, keyed by app (`AudioApp.key`), and nothing is
/// written to disk: quitting MaxCandela puts every app back to its own
/// level. A setting outlives the app's processes for the rest of the run, so
/// an app that quits and relaunches comes back at the level it was given.
///
/// The taps follow the settings via `reconcile()`, which runs when a setting
/// changes, when the HAL's process list changes (an app started or stopped
/// using audio, or quit) and when the default output device changes.
@available(macOS 14.2, *)
final class AppVolumeEngine {
    struct Setting: Equatable {
        var percent: Double = AppVolumeMath.unityPercent
        var muted = false
        var gain: Float { muted ? 0 : AppVolumeMath.gain(percent: percent) }
        var isNeutral: Bool { !AppVolumeMath.needsTap(percent: percent, muted: muted) }
    }

    private(set) var settings: [String: Setting] = [:]
    private(set) var apps: [AudioApp] = []
    /// The last thing that went wrong, for the menu. Cleared by Reset All.
    private(set) var lastFailure: String?

    private var sessions: [String: ProcessTapSession] = [:]
    private var sessionDevice: AudioDeviceID?
    /// Apps whose tap failed to start. Their slider does nothing until the
    /// menu is opened again (`retryFailed`), rather than retrying — and
    /// failing — on every step of a drag.
    private var failedKeys: Set<String> = []
    /// Back at 100%: the tap is torn down after a pause, so dragging the
    /// slider *through* 100% doesn't destroy and rebuild it on the way.
    private var pendingRemovals: [String: DispatchWorkItem] = [:]
    private static let removalDelay: TimeInterval = 1.5
    private var reconcileScheduled = false
    private var listeners: [(AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []

    init() {
        listen(to: kAudioHardwarePropertyProcessObjectList)
        listen(to: kAudioHardwarePropertyDefaultOutputDevice)
    }

    // MARK: - Reading

    /// Re-reads the HAL's clients and groups them into apps.
    func refreshApps() {
        let appIDs = Set(NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy != .prohibited }
            .compactMap(\.bundleIdentifier))
        apps = AppVolumeModel.group(AudioProcessList.current(), appBundleIDs: appIDs,
                                    excludingPID: ProcessInfo.processInfo.processIdentifier)
    }

    func setting(for key: String) -> Setting { settings[key] ?? Setting() }

    var hasAdjustments: Bool { !settings.isEmpty }

    /// A tap that has run for a while and delivered nothing but zeros. With
    /// the "System Audio Recording" permission refused, a tap is expected to
    /// deliver silence rather than fail — so the app goes quiet and nothing
    /// reports why. An app that is merely playing digital silence looks the
    /// same, which is why the menu only *suggests* checking the permission.
    var looksUnauthorised: Bool {
        sessions.values.contains { session in
            let counters = session.counters
            return Date().timeIntervalSince(session.startedAt) > 3
                && counters.callbacks > 100 && counters.audible == 0
        }
    }

    // MARK: - Changing

    func setPercent(_ percent: Double, for key: String) {
        var setting = self.setting(for: key)
        setting.percent = AppVolumeMath.snapped(percent)
        apply(setting, for: key)
    }

    func setMuted(_ muted: Bool, for key: String) {
        var setting = self.setting(for: key)
        setting.muted = muted
        apply(setting, for: key)
    }

    /// Every app back to its own level, every tap gone, now.
    func resetAll() {
        pendingRemovals.values.forEach { $0.cancel() }
        pendingRemovals.removeAll()
        settings.removeAll()
        stopAllSessions()
        failedKeys.removeAll()
        lastFailure = nil
    }

    /// The menu was opened again: let apps whose tap failed try once more.
    func retryFailed() {
        failedKeys.removeAll()
    }

    /// Quit or Pro lapsed: nothing of ours may stay in the audio path.
    func shutdown() {
        resetAll()
        listeners.forEach { address, block in
            var address = address
            AudioObjectRemovePropertyListenerBlock(TapHAL.system, &address, .main, block)
        }
        listeners.removeAll()
    }

    private func apply(_ setting: Setting, for key: String) {
        guard !failedKeys.contains(key) else { return }
        pendingRemovals.removeValue(forKey: key)?.cancel()
        settings[key] = setting
        if let session = sessions[key] {
            session.setGain(setting.gain)
        } else if !setting.isNeutral, !reconcile() {
            // Only for the user's own change: reconcile also runs on HAL
            // notifications, where a beep would come out of nowhere.
            NSSound.beep()
        }
        if setting.isNeutral {
            let removal = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.pendingRemovals[key] = nil
                if self.settings[key]?.isNeutral == true { self.settings[key] = nil }
                self.reconcile()
            }
            pendingRemovals[key] = removal
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.removalDelay, execute: removal)
        }
    }

    // MARK: - Following the system

    /// Brings the live taps in line with the settings and the processes that
    /// exist now. False when a tap that should have started didn't.
    @discardableResult
    func reconcile() -> Bool {
        guard !settings.isEmpty || !sessions.isEmpty else { return true }
        refreshApps()

        // A new default output: every tap is playing to the old one.
        let device = AudioDevices.defaultDevice(input: false)
        if device != sessionDevice {
            stopAllSessions()
            sessionDevice = device
        }

        // A setting back at 100% keeps a live tap until its removal fires,
        // but never starts one.
        var wanted: [String: Set<AudioObjectID>] = [:]
        for (key, setting) in settings where !setting.isNeutral || sessions[key] != nil {
            wanted[key] = Set(apps.first { $0.key == key }?.processObjectIDs ?? [])
        }
        let plan = AppVolumeModel.plan(wanted: wanted, running: sessions.mapValues(\.processObjectIDs))
        for key in plan.stop + plan.rebuild {
            sessions.removeValue(forKey: key)?.stop()
        }
        guard let device else {
            guard (plan.start + plan.rebuild).isEmpty else {
                lastFailure = "No output device"
                return false
            }
            return true
        }
        var allStarted = true
        for key in plan.rebuild + plan.start {
            guard let processes = wanted[key] else { continue }
            switch ProcessTapSession.start(processes: processes, outputDevice: device,
                                           gain: setting(for: key).gain) {
            case .success(let session):
                sessions[key] = session
                lastFailure = nil
            case .failure(let failure):
                // Forget the setting, or every process-list change would
                // retry and fail again. The row goes back to 100%; the app
                // keeps playing untouched.
                settings[key] = nil
                failedKeys.insert(key)
                lastFailure = failure.message
                allStarted = false
                NSLog("MaxCandela: App Volume for \(key): \(failure.message)")
            }
        }
        return allStarted
    }

    private func stopAllSessions() {
        sessions.values.forEach { $0.stop() }
        sessions.removeAll()
    }

    /// HAL notifications arrive in bursts (one app launching can change the
    /// process list several times), so they are coalesced into one pass.
    private func scheduleReconcile() {
        guard !reconcileScheduled else { return }
        reconcileScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.reconcileScheduled = false
            self?.reconcile()
        }
    }

    private func listen(to selector: AudioObjectPropertySelector) {
        var address = TapHAL.address(selector)
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.scheduleReconcile() }
        if AudioObjectAddPropertyListenerBlock(TapHAL.system, &address, .main, block) == noErr {
            listeners.append((address, block))
        }
    }
}
