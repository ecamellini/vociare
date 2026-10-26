import AVFoundation
import FluidAudio

/// Captures the default microphone into memory and reports its level for the overlay.
@MainActor
final class Recorder {
    private var engine: AVAudioEngine?
    private var format: AVAudioFormat?
    private var configurationObserver: NSObjectProtocol?
    private let buffer = SampleBuffer()

    /// `onReady` fires with the first captured audio.
    func start(
        voiceProcessing: Bool, onReady: @escaping @MainActor () -> Void, onLevel: @escaping @MainActor (Float) -> Void
    ) throws {
        // A fresh engine per recording picks up input device changes (e.g. headphones plugged in).
        let engine = AVAudioEngine()
        if voiceProcessing {
            try engine.inputNode.setVoiceProcessingEnabled(true)
            // By default voice processing turns other audio down while recording.
            engine.inputNode.voiceProcessingOtherAudioDuckingConfiguration = .init(
                enableAdvancedDucking: false, duckingLevel: .min)
        }
        buffer.reset()
        let tap = Tap(buffer: buffer, onReady: onReady, onLevel: onLevel)
        format = try tap.install(on: engine.inputNode)
        try engine.start()
        // Voice processing's aggregate device can reconfigure right after start, and a device can change
        // mid-recording: either stops the engine, which doesn't restart on its own.
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.engine === engine, !engine.isRunning else { return }
                engine.inputNode.removeTap(onBus: 0)
                self.format = try? tap.install(on: engine.inputNode)
                try? engine.start()
            }
        }
        self.engine = engine
    }

    /// Stops capturing and returns the recording as 16 kHz mono, the format Parakeet expects.
    func stop() throws -> [Float] {
        if let configurationObserver { NotificationCenter.default.removeObserver(configurationObserver) }
        configurationObserver = nil
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
    nonisolated static func normalizedLevel(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let rms = sqrt(samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count))
        let db = 20 * log10(max(rms, 1e-7))
        return min(max((db + 50) / 50, 0), 1)
    }
}

/// Feeds one recording's buffer from the input node; reinstalled with the new format after a reconfiguration.
private final class Tap: @unchecked Sendable {
    private let buffer: SampleBuffer
    private let onReady: @MainActor () -> Void
    private let onLevel: @MainActor (Float) -> Void
    // Only touched from the tap block, which runs serially on the audio thread.
    private var notifiedReady = false

    init(buffer: SampleBuffer, onReady: @escaping @MainActor () -> Void, onLevel: @escaping @MainActor (Float) -> Void) {
        self.buffer = buffer
        self.onReady = onReady
        self.onLevel = onLevel
    }

    func install(on input: AVAudioInputNode) throws -> AVAudioFormat {
        let format = input.outputFormat(forBus: 0)
        // With no input device the format is empty, and installing a tap on it raises an exception.
        guard format.sampleRate > 0, format.channelCount > 0 else { throw RecorderError.noInputDevice }
        // Voice processing adds channels and puts the cleaned voice in the first; reading channel 0
        // through floatChannelData only works on non-interleaved float.
        guard format.commonFormat == .pcmFormatFloat32, !format.isInterleaved else { throw RecorderError.unsupportedFormat }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [self] pcm, _ in
            guard let channel = pcm.floatChannelData?[0] else { return }
            if !notifiedReady {
                notifiedReady = true
                let onReady = self.onReady
                Task { @MainActor in onReady() }
            }
            let samples = Array(UnsafeBufferPointer(start: channel, count: Int(pcm.frameLength)))
            buffer.append(samples)
            let level = Recorder.normalizedLevel(samples)
            let onLevel = self.onLevel
            Task { @MainActor in onLevel(level) }
        }
        return format
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
