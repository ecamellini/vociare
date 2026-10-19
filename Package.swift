// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Vociare",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.9.1")
    ],
    targets: [
        .executableTarget(
            name: "Vociare",
            dependencies: [.product(name: "FluidAudio", package: "FluidAudio")],
            // FluidAudio's AsrManager is not Sendable, which Swift 6 strict concurrency rejects.
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
