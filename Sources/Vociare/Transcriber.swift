import FluidAudio
import Foundation
import OSLog

/// Loads Parakeet on first use and unloads it after `idleTimeout` without transcriptions,
/// so the model only holds memory while dictation is actually being used.
@MainActor
final class Transcriber {
    private static let sampleRate = 16_000
    // The default 6-bit encoder corrupts words in some contexts (FluidAudio #760): on a real Italian meeting it
    // wrote "Querfetto" and "tuo balletto" where this one got "Quel perfetto" and "tovagliato".
    nonisolated static let encoderPrecision = ParakeetEncoderPrecision.int8V2
    private let logger = Logger(subsystem: "me.ecamel.vociare", category: "Transcriber")
    private let idleTimeout: Duration
    private var loading: Task<AsrManager, Error>?
    private var isReady = false
    private var unloadTask: Task<Void, Never>?
    // One at a time, so dictations finish in the order they were spoken.
    private var lastTranscription: Task<Void, Never>?

    init(idleTimeout: Duration) {
        self.idleTimeout = idleTimeout
    }

    enum ModelState { case unloaded, loading, ready }

    var modelState: ModelState { loading == nil ? .unloaded : isReady ? .ready : .loading }

    /// Starts loading in the background, so the model is ready by the time the user stops speaking.
    func warmUp() {
        unloadTask?.cancel()
        _ = loadingTask()
    }

    /// `latinScriptOnly` drops Cyrillic and Greek tokens, which Parakeet sometimes emits for Latin-script speech.
    func transcribe(_ samples: [Float], latinScriptOnly: Bool = false) async throws -> String {
        unloadTask?.cancel()
        let previous = lastTranscription
        let transcription = Task {
            await previous?.value
            let manager = try await loadingTask().value
            // FluidAudio rejects very short clips; a second of audio is always enough.
            let padded = samples + Array(repeating: 0, count: max(0, Self.sampleRate - samples.count))
            var state = TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
            // The hint only filters by script, so any Latin-script language works; French would also
            // block some English tokens.
            let result = try await manager.transcribe(
                padded, decoderState: &state, language: latinScriptOnly ? .english : nil)
            return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        lastTranscription = Task { _ = await transcription.result }
        defer { scheduleUnload() }
        return try await transcription.value
    }

    private func loadingTask() -> Task<AsrManager, Error> {
        if let loading { return loading }
        let task = Task {
            let start = ContinuousClock.now
            let models = try await AsrModels.downloadAndLoad(version: .v3, encoderPrecision: Self.encoderPrecision)
            let manager = AsrManager(config: .default)
            try await manager.loadModels(models)
            self.logger.info("Model loaded in \(ContinuousClock.now - start, privacy: .public)")
            self.isReady = true
            return manager
        }
        loading = task
        Task {
            if case .failure(let error) = await task.result {
                logger.error("Model load failed: \(error, privacy: .public)")
                if loading == task { loading = nil }
            }
        }
        return task
    }

    private func scheduleUnload() {
        unloadTask?.cancel()
        unloadTask = Task {
            try? await Task.sleep(for: idleTimeout)
            guard !Task.isCancelled else { return }
            // Dropping the manager releases the Core ML models.
            loading = nil
            isReady = false
            logger.info("Model unloaded after idle timeout")
        }
    }
}
