// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MaxCandela",
    // Dev-only floor for `swift run`/`swift test`. The SHIPPING minimum is set
    // by the Xcode build: Resources/Info.plist (LSMinimumSystemVersion) and
    // project.yml (deploymentTarget) — currently macOS 15.6. Kept at 14 here
    // (not 15) because .v15 needs Swift 6 tools (strict concurrency); 14 is the
    // floor for the `NSView.displayLink` API the renderer uses.
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MaxCandela", targets: ["MaxCandela"])
    ],
    targets: [
        .executableTarget(
            name: "MaxCandela",
            path: "Sources/MaxCandela",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "MaxCandelaTests",
            dependencies: ["MaxCandela"],
            path: "Tests/MaxCandelaTests"
        )
    ]
)
