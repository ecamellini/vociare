// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Vociare",
    platforms: [.macOS(.v14)],
    dependencies: [
        // `traits: []` links ASR and VAD only. Exact, because a new version can change transcriptions:
        // compare `--transcribe` output before and after moving.
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.18.2", traits: [])
    ],
    targets: [
        .executableTarget(
            name: "Vociare",
            dependencies: [.product(name: "FluidAudio", package: "FluidAudio")],
            // Swift 6 mode still rejects this code (timers sent across isolation, C globals); migrating
            // is a change of its own.
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
