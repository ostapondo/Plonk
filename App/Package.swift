// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "plonk",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "plonk",
            path: "Sources/plonk",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "plonkTests",
            dependencies: ["plonk"],
            path: "Tests/plonkTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
