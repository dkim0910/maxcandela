// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MaxCandela",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MaxCandela", targets: ["MaxCandela"])
    ],
    targets: [
        .executableTarget(
            name: "MaxCandela",
            path: "Sources/MaxCandela"
        ),
        .testTarget(
            name: "MaxCandelaTests",
            dependencies: ["MaxCandela"],
            path: "Tests/MaxCandelaTests"
        )
    ]
)
