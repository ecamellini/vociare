import AVFoundation
import FluidAudio

/// Captures the default microphone into memory and reports its level for the overlay.
@MainActor
final class Recorder {
    private var engine: AVAudioEngine?
    private var format: AVAudioFormat?
    private let buffer = SampleBuffer()

    /// `onReady` fires with the first captured audio.
    func start(
        voiceProcessing: Bool, onReady: @escaping @MainActor () -> Void, onLevel: @escaping @MainActor (Float) -> Void
    ) throws {
        // A fresh engine per recording picks up input device changes (e.g. headphones plugged in).
        let engine = AVAudioEngine()
        let input = engine.inputNode
        if voiceProcessing {
            try input.setVoiceProcessingEnabled(true)
            // By default voice processing turns other audio down while recording.
            input.voiceProcessingOtherAudioDuckingConfiguration = .init(enableAdvancedDucking: false, duckingLevel: .min)
        }
        let format = input.outputFormat(forBus: 0)
        // With no input device the format is empty, and installing a tap on it raises an exception.
        guard format.sampleRate > 0, format.channelCount > 0 else { throw RecorderError.noInputDevice }
        // Voice processing adds channels and puts the cleaned voice in the first; reading channel 0
        // through floatChannelData only works on non-interleaved float.
        guard format.commonFormat == .pcmFormatFloat32, !format.isInterleaved else { throw RecorderError.unsupportedFormat }
        let buffer = self.buffer
        buffer.reset()
        var notifiedReady = false
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { pcm, _ in
            guard let channel = pcm.floatChannelData?[0] else { return }
            if !notifiedReady {
                notifiedReady = true
                Task { @MainActor in onReady() }
            }
            let samples = Array(UnsafeBufferPointer(start: channel, count: Int(pcm.frameLength)))
            buffer.append(samples)
            let level = Self.normalizedLevel(samples)
            Task { @MainActor in onLevel(level) }
        }
        try engine.start()
        self.engine = engine
        self.format = format
    }

    /// Stops capturing and returns the recording as 16 kHz mono, the format Parakeet expects.
    func stop() throws -> [Float] {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        let samples = buffer.drain()
        guard let format, !samples.isEmpty,
            let mono = AVAudioFormat(standardFormatWithSampleRate: format.sampleRate, channels: 1),
            let pcm = AVAudioPCMBuffer(pcmFormat: mono, frameCapacity: AVAudioFrameCount(samples.count))
        else { return [] }
        pcm.frameLength = pcm.frameCapacity
        samples.withUnsafeBufferPointer { pcm.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
        return try AudioConverter().resampleBuffer(pcm)
    }

    /// Maps RMS from -50…0 dBFS to 0…1, the range where speech actually moves the bars.
    nonisolated private static func normalizedLevel(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let rms = sqrt(samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count))
        let db = 20 * log10(max(rms, 1e-7))
        return min(max((db + 50) / 50, 0), 1)
    }
}

enum RecorderError: Error {
    case noInputDevice
    case unsupportedFormat
}

/// The audio tap runs on a realtime thread, so samples cross to the main actor through a lock.
private final class SampleBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var samples: [Float] = []

    func reset() { lock.withLock { samples = [] } }
    func append(_ chunk: [Float]) { lock.withLock { samples += chunk } }
    func drain() -> [Float] { lock.withLock { defer { samples = [] }; return samples } }
}
