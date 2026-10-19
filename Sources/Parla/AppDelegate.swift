import AVFoundation
import AppKit
import OSLog
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let logger = Logger(subsystem: "me.ecamel.parla", category: "App")
    private let transcriber = Transcriber(idleTimeout: .seconds(10 * 60))
    private let recorder = Recorder()
    private let overlay = Overlay()
    private let startSound = Chime.start
    private let stopSound = Chime.stop
    private lazy var hotkey = HotkeyMonitor(
        holdThreshold: 0.25,
        onStart: { [weak self] in self?.startDictation() },
        onStop: { [weak self] in self?.stopDictation() }
    )
    private var statusItem: NSStatusItem?
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private lazy var loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    private let pasteLastItem = NSMenuItem(title: "Paste Last Dictation", action: nil, keyEquivalent: "")
    private let recentItem = NSMenuItem(title: "Recent", action: nil, keyEquivalent: "")
    private var isRecording = false
    // In memory only, so dictated text never lands on disk.
    private var history: [String] = []
    private static let historyLimit = 10

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = ParlaIcon.menuBarImage(recording: false)
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(statusLine)
        menu.addItem(.separator())
        pasteLastItem.target = self
        pasteLastItem.action = #selector(pasteFromHistory(_:))
        menu.addItem(pasteLastItem)
        recentItem.submenu = NSMenu()
        menu.addItem(recentItem)
        menu.addItem(.separator())
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(NSMenuItem(title: "Quit Parla", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item

        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        hotkey.start()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        statusLine.title =
            !hotkey.isRunning ? "Needs Accessibility permission"
            : transcriber.isLoaded ? "Hold right ⌘ to dictate · model in memory"
            : "Hold right ⌘ to dictate · model unloaded"
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        pasteLastItem.representedObject = history.first
        pasteLastItem.isEnabled = !history.isEmpty
        recentItem.isEnabled = !history.isEmpty
        recentItem.submenu?.items = history.map { text in
            let item = NSMenuItem(title: Self.menuTitle(text), action: #selector(pasteFromHistory(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = text
            item.toolTip = text
            return item
        }
    }

    /// Pastes into whichever field has focus: a menu bar menu doesn't take focus from the app underneath.
    @objc private func pasteFromHistory(_ sender: NSMenuItem) {
        guard let text = sender.representedObject as? String else { return }
        // Cmd+V posted while the menu is still closing can reach the menu instead of the app.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { Paster.paste(text) }
    }

    private static func menuTitle(_ text: String) -> String {
        let line = text.replacingOccurrences(of: "\n", with: " ")
        return line.count > 60 ? line.prefix(60) + "…" : line
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            let service = SMAppService.mainApp
            try service.status == .enabled ? service.unregister() : service.register()
        } catch {
            logger.error("Launch at login change failed: \(error)")
        }
    }

    private func startDictation() {
        transcriber.warmUp()
        do {
            try recorder.start { [weak self] level in self?.overlay.push(level: level) }
        } catch {
            logger.error("Microphone failed to start: \(error, privacy: .public)")
            return
        }
        isRecording = true
        statusItem?.button?.image = ParlaIcon.menuBarImage(recording: true)
        overlay.show()
        startSound?.play()
        logger.notice("Dictation started")
    }

    private func stopDictation() {
        guard isRecording else { return }
        isRecording = false
        statusItem?.button?.image = ParlaIcon.menuBarImage(recording: false)
        stopSound?.play()
        overlay.showTranscribing()
        Task {
            defer { overlay.hide() }
            do {
                let text = try await transcriber.transcribe(try recorder.stop())
                logger.notice("Transcribed \(text.count) characters")
                guard !text.isEmpty else { return }
                history = Array(([text] + history).prefix(Self.historyLimit))
                Paster.paste(text)
            } catch {
                logger.error("Transcription failed: \(error, privacy: .public)")
            }
        }
    }
}
