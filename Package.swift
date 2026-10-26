// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Vociare",
    platforms: [.macOS(.v14)],
    dependencies: [
        // A commit past v0.17.7: the TTS and diarization traits that `traits: []` turns off came after it,
        // so `traits: []` links ASR and VAD only. Move to the next tag once it has them. Moving can change
        // transcriptions: compare `--transcribe` output before and after.
        .package(
            url: "https://github.com/FluidInference/FluidAudio.git",
            revision: "61d41b3ca04833d1cb80632c82ba401f117a01ef", traits: [])
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
