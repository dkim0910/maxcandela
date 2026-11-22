// swift-tools-version:5.9
import PackageDescription

// TapSpike: a standalone proof for MaxCandela's App Volume tool. It taps one
// process by PID, plays it back at a chosen gain for N seconds, tears down,
// and prints the OSStatus of every Core Audio call on the way. See the header
// of Sources/TapSpike/main.swift and run-sandboxed.sh.
let package = Package(
    name: "TapSpike",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "TapSpike", path: "Sources/TapSpike"),
    ]
)
