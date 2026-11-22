import CoreAudio
import Foundation

/// One Core Audio *process object*: a process connected to the audio server
/// (`kAudioHardwarePropertyProcessObjectList`). Not every app has one — only
/// those that have opened audio — and many apps play through a helper
/// process rather than themselves.
struct AudioProcessInfo: Equatable {
    let objectID: AudioObjectID
    let pid: pid_t
    let bundleID: String?
    /// `kAudioProcessPropertyIsRunningOutput`: sound is being played now.
    let isRunningOutput: Bool
}

/// What App Volume shows as one row: an app together with every helper
/// process that plays sound on its behalf.
struct AudioApp: Equatable {
    /// The app's bundle ID, or "pid:<n>" for a process without one.
    let key: String
    /// Sorted. A tap covers all of them, so a helper that starts playing
    /// later is already included.
    var processObjectIDs: [AudioObjectID]
    var pids: [pid_t]
    var isPlaying: Bool
}

/// What to do to the live taps after the process list or a setting changed.
struct TapPlan: Equatable {
    var start: [String] = []
    var rebuild: [String] = []
    var stop: [String] = []
    var isEmpty: Bool { start.isEmpty && rebuild.isEmpty && stop.isEmpty }
}

/// The bookkeeping half of App Volume — which process belongs to which app,
/// which taps to create or destroy, and where in the HAL's buffer lists the
/// audio lives. Pure and unit-tested; the Core Audio calls are in
/// `ProcessTap.swift`.
enum AppVolumeModel {

    // MARK: - Processes → apps

    /// The app a Core Audio client belongs to.
    ///
    /// Browsers and Electron apps play sound from helpers whose bundle IDs
    /// extend the app's own ("com.google.Chrome.helper"), so a helper is
    /// filed under the running app whose bundle ID is its longest dotted
    /// prefix. `appBundleIDs` must hold only real apps (regular or accessory
    /// activation policy) — helpers are running applications too, and would
    /// otherwise match themselves. Without a public way to ask macOS which
    /// app is *responsible* for a process, anything else (WebKit's shared
    /// "com.apple.WebKit.GPU", for one) stands as its own row.
    static func appKey(bundleID: String?, pid: pid_t, appBundleIDs: Set<String>) -> String {
        guard let bundleID, !bundleID.isEmpty else { return "pid:\(pid)" }
        if appBundleIDs.contains(bundleID) { return bundleID }
        let parent = appBundleIDs
            .filter { bundleID.hasPrefix($0 + ".") }
            .max { $0.count < $1.count }
        return parent ?? bundleID
    }

    /// Groups process objects into apps. Our own process is left out — its
    /// aggregate devices play everyone else's sound and must never be tapped.
    static func group(_ processes: [AudioProcessInfo], appBundleIDs: Set<String>,
                      excludingPID ownPID: pid_t) -> [AudioApp] {
        var byKey: [String: AudioApp] = [:]
        var order: [String] = []
        for process in processes where process.pid != ownPID {
            let key = appKey(bundleID: process.bundleID, pid: process.pid, appBundleIDs: appBundleIDs)
            if var app = byKey[key] {
                app.processObjectIDs.append(process.objectID)
                if !app.pids.contains(process.pid) { app.pids.append(process.pid) }
                app.isPlaying = app.isPlaying || process.isRunningOutput
                byKey[key] = app
            } else {
                order.append(key)
                byKey[key] = AudioApp(key: key, processObjectIDs: [process.objectID],
                                      pids: [process.pid], isPlaying: process.isRunningOutput)
            }
        }
        return order.compactMap { key in
            guard var app = byKey[key] else { return nil }
            app.processObjectIDs.sort()
            app.pids.sort()
            return app
        }
    }

    /// The rows in the menu: everything playing now, plus anything that has
    /// a setting (so a paused app at 30% can still be put back).
    static func visibleApps(_ apps: [AudioApp], adjusted: Set<String>) -> [AudioApp] {
        apps.filter { $0.isPlaying || adjusted.contains($0.key) }
    }

    /// Diffs the taps that should exist against those that do.
    ///
    /// - `wanted`: every app with a setting → the process objects it has now
    ///   (empty when the app has quit).
    /// - `running`: every live tap → the process objects it was built for.
    ///
    /// A tap whose app quit is stopped; one whose app gained or lost a
    /// helper is rebuilt, since a tap's process list is fixed at creation.
    static func plan(wanted: [String: Set<AudioObjectID>],
                     running: [String: Set<AudioObjectID>]) -> TapPlan {
        var plan = TapPlan()
        for (key, processes) in running {
            guard let now = wanted[key], !now.isEmpty else { plan.stop.append(key); continue }
            if now != processes { plan.rebuild.append(key) }
        }
        for (key, processes) in wanted where !processes.isEmpty && running[key] == nil {
            plan.start.append(key)
        }
        plan.start.sort()
        plan.rebuild.sort()
        plan.stop.sort()
        return plan
    }

    // MARK: - Buffer layout

    /// Which of the aggregate device's input streams is the tap.
    ///
    /// The aggregate holds the output device and the tap; its input streams
    /// are the output device's own (a headset's microphone, say) followed by
    /// the tap's single stream. Anything other than exactly one extra stream
    /// is a layout this code does not understand, and nil stops the tap from
    /// starting rather than guessing.
    static func tapStreamIndex(aggregateInputStreams: Int, deviceInputStreams: Int) -> Int? {
        guard deviceInputStreams >= 0, aggregateInputStreams == deviceInputStreams + 1 else { return nil }
        return aggregateInputStreams - 1
    }

    /// `kAudioDevicePropertyIOProcStreamUsage` flags for the input side: on
    /// for the tap, off for every hardware input. Without this a headset or
    /// USB interface would have its microphone switched on — a microphone
    /// prompt, the orange indicator, and Bluetooth headphones dropping to
    /// call quality — for audio we never read.
    static func inputStreamUsage(inputStreams: Int, tapIndex: Int) -> [UInt32] {
        (0..<max(0, inputStreams)).map { $0 == tapIndex ? 1 : 0 }
    }

    /// Where 0-based channel `channel` of a device lives, given the channel
    /// count of each of its streams (the HAL hands an IO proc one interleaved
    /// buffer per stream).
    static func channelLocation(_ channel: Int, streamChannelCounts: [Int]) -> (buffer: Int, channel: Int)? {
        guard channel >= 0 else { return nil }
        var remaining = channel
        for (buffer, count) in streamChannelCounts.enumerated() {
            if remaining < count { return (buffer, remaining) }
            remaining -= max(0, count)
        }
        return nil
    }

    /// Where to write left and right. Uses the device's own stereo pair
    /// (`kAudioDevicePropertyPreferredChannelsForStereo`, 1-based) when it
    /// names channels that exist, else the first two. A single-channel
    /// device gets no right channel — the caller mixes to mono.
    static func stereoLocations(preferred: (left: UInt32, right: UInt32)?, streamChannelCounts: [Int])
        -> (left: (buffer: Int, channel: Int), right: (buffer: Int, channel: Int)?)? {
        let total = streamChannelCounts.reduce(0) { $0 + max(0, $1) }
        guard total > 0 else { return nil }
        if let preferred, preferred.left >= 1, preferred.right >= 1, preferred.left != preferred.right,
           let left = channelLocation(Int(preferred.left) - 1, streamChannelCounts: streamChannelCounts),
           let right = channelLocation(Int(preferred.right) - 1, streamChannelCounts: streamChannelCounts) {
            return (left, right)
        }
        guard let left = channelLocation(0, streamChannelCounts: streamChannelCounts) else { return nil }
        return (left, channelLocation(1, streamChannelCounts: streamChannelCounts))
    }

    /// HAL errors are four-character codes ('!dev', 'who?'); show them that
    /// way when they are printable, as a number otherwise.
    static func describe(status: OSStatus) -> String {
        let bytes = withUnsafeBytes(of: UInt32(bitPattern: status).bigEndian) { Array($0) }
        guard bytes.allSatisfy({ (0x20...0x7E).contains($0) }) else { return "\(status)" }
        return "'\(String(decoding: bytes, as: UTF8.self))'"
    }

    /// The render code reads and writes 32-bit native floats and nothing
    /// else; any other stream format leaves the app alone.
    static func isFloat32PCM(_ format: AudioStreamBasicDescription) -> Bool {
        format.mFormatID == kAudioFormatLinearPCM
            && format.mFormatFlags & kAudioFormatFlagIsFloat != 0
            && format.mFormatFlags & kAudioFormatFlagIsBigEndian == 0
            && format.mBitsPerChannel == 32
    }
}
