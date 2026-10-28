import AppKit
import FluidAudio
import ServiceManagement

@main
enum Vociare {
    @MainActor static func main() {
        let arguments = CommandLine.arguments
        if arguments.count == 3, arguments[1] == "--transcribe" {
            Task {
                await transcribeFile(arguments[2])
                exit(0)
            }
            RunLoop.main.run()
        }
        if arguments.count == 2, arguments[1] == "--download-model" {
            Task {
                do {
                    print("Downloading the Parakeet model (~600 MB) if missing, then loading it once...")
                    try await Transcriber.download()
                    print("Model ready")
                    exit(0)
                } catch {
                    print("Failed: \(error)")
                    exit(1)
                }
            }
            RunLoop.main.run()
        }
        // Login items outlive the app bundle, so uninstall.sh asks the app to remove its own before deleting it.
        if arguments.count == 2, arguments[1] == "--unregister-login-item" {
            try? SMAppService.mainApp.unregister()
            exit(0)
        }
        if arguments.count == 3, arguments[1] == "--render-icon" {
            do {
                try VociareIcon.writeIconSet(to: URL(fileURLWithPath: arguments[2]))
                exit(0)
            } catch {
                print("Failed: \(error)")
                exit(1)
            }
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    /// Runs the dictation pipeline on an audio file, to check the model without a microphone.
    @MainActor private static func transcribeFile(_ path: String) async {
        let transcriber = Transcriber(idleTimeout: .seconds(60))
        do {
            let samples = try AudioConverter().resampleAudioFile(URL(fileURLWithPath: path))
            let latinScriptOnly = UserDefaults.standard.bool(forKey: AppDelegate.latinScriptOnlyKey)
            let clock = ContinuousClock()
            let cold = try await clock.measure {
                print(Replacements.apply(to: try await transcriber.transcribe(samples, latinScriptOnly: latinScriptOnly)))
            }
            let warm = try await clock.measure { _ = try await transcriber.transcribe(samples, latinScriptOnly: latinScriptOnly) }
            print("cold: \(cold), warm: \(warm)")
        } catch {
            print("Failed: \(error)")
        }
    }
}
