// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Vociare",
    platforms: [.macOS(.v14)],
    dependencies: [
        // A commit past 0.9.1, the last tag, for the language hint that keeps Cyrillic out. Moving it can
        // change transcriptions: compare `--transcribe` output before and after.
        // `traits: []` links ASR and VAD only: no TTS, diarization or prebuilt text-normalization binary.
        .package(
            url: "https://github.com/FluidInference/FluidAudio.git",
            revision: "61d41b3ca04833d1cb80632c82ba401f117a01ef", traits: [])
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
