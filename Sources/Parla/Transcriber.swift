import FluidAudio
import Foundation
import OSLog

// Parla only ever uses one manager at a time, from the main actor.
extension AsrManager: @retroactive @unchecked Sendable {}

/// Loads Parakeet on first use and unloads it after `idleTimeout` without transcriptions,
/// so the model only holds memory while dictation is actually being used.
@MainActor
final class Transcriber {
    private static let sampleRate = 16_000
    private let logger = Logger(subsystem: "me.ecamel.parla", category: "Transcriber")
    private let idleTimeout: Duration
    private var loading: Task<AsrManager, Error>?
    private var unloadTask: Task<Void, Never>?

    init(idleTimeout: Duration) {
        self.idleTimeout = idleTimeout
    }

    var isLoaded: Bool { loading != nil }

    /// Starts loading in the background, so the model is ready by the time the user stops speaking.
    func warmUp() {
        unloadTask?.cancel()
        _ = loadingTask()
    }

    func transcribe(_ samples: [Float]) async throws -> String {
        unloadTask?.cancel()
        defer { scheduleUnload() }
        let manager = try await loadingTask().value
        // Parakeet rejects clips shorter than one second.
        let padded = samples + Array(repeating: 0, count: max(0, Self.sampleRate - samples.count))
        let result = try await manager.transcribe(padded, source: .microphone)
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadingTask() -> Task<AsrManager, Error> {
        if let loading { return loading }
        let task = Task {
            let start = ContinuousClock.now
            let models = try await AsrModels.downloadAndLoad(version: .v3)
            let manager = AsrManager(config: .default)
            try await manager.initialize(models: models)
            self.logger.info("Model loaded in \(ContinuousClock.now - start, privacy: .public)")
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
            // Dropping the manager releases the Core ML models; AsrManager.cleanup() keeps a reference to them.
            loading = nil
            logger.info("Model unloaded after idle timeout")
        }
    }
}
