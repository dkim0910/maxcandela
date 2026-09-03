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
    dependencies: [
        // RevenueCat, in "purchases completed by my app" mode: StoreManager
        // keeps doing the StoreKit 2 work, RevenueCat only *records* installs
        // and purchases so trial → paid conversion is visible on its charts.
        // Mirror of purchases-ios that ships only the SPM sources (faster clone).
        // Keep the version in step with project.yml (the Xcode/App Store build).
        .package(url: "https://github.com/RevenueCat/purchases-ios-spm.git", from: "5.87.1")
    ],
    targets: [
        .executableTarget(
            name: "MaxCandela",
            dependencies: [
                .product(name: "RevenueCat", package: "purchases-ios-spm")
            ],
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
