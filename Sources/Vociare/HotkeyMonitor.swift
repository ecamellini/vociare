import AppKit
import Carbon.HIToolbox
import OSLog

/// Reports long presses of right Command, and Esc during one. A short tap, a Command+key combo or a Command+click
/// stays a normal one.
@MainActor
final class HotkeyMonitor {
    // Device-dependent flag for the right Command key (NX_DEVICERCMDKEYMASK).
    private static let rightCommandMask: UInt64 = 0x10
    private let logger = Logger(subsystem: "me.ecamel.vociare", category: "Hotkey")
    private let holdThreshold: TimeInterval
    private let onStart: () -> Void
    private let onStop: () -> Void
    private let onCancel: () -> Void
    private var tap: CFMachPort?
    private var retryTimer: Timer?
    private var holdTimer: Timer?
    private var isPressed = false
    private var isActive = false

    init(holdThreshold: TimeInterval, onStart: @escaping () -> Void, onStop: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.holdThreshold = holdThreshold
        self.onStart = onStart
        self.onStop = onStop
        self.onCancel = onCancel
    }

    var isRunning: Bool { tap != nil }

    /// Keeps retrying until the tap can be created, so granting Accessibility works without a relaunch.
    func start() {
        guard !installTap() else { return }
        retryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                if self?.installTap() ?? true { timer.invalidate() }
            }
        }
    }

    private func installTap() -> Bool {
        let mask = [CGEventType.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown]
            .reduce(CGEventMask(0)) { $0 | CGEventMask(1 << $1.rawValue) }
        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .listenOnly,
                eventsOfInterest: mask,
                callback: { _, type, event, userInfo in
                    let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(userInfo!).takeUnretainedValue()
                    MainActor.assumeIsolated { monitor.handle(type, event) }
                    return Unmanaged.passUnretained(event)
                },
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            )
        else {
            logger.notice("Event tap not available yet: Accessibility not granted")
            return false
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        self.tap = tap
        logger.notice("Listening for right Command")
        return true
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .keyDown where isActive && event.getIntegerValueField(.keyboardEventKeycode) == kVK_Escape:
            // Releasing the key afterwards does nothing.
            isActive = false
            onCancel()
        case .keyDown, .leftMouseDown, .rightMouseDown:
            holdTimer?.invalidate()
        case .flagsChanged where event.getIntegerValueField(.keyboardEventKeycode) == kVK_RightCommand:
            let pressed = event.flags.rawValue & Self.rightCommandMask != 0
            pressed ? press() : release()
        default:
            break
        }
    }

    private func press() {
        guard !isPressed else { return }
        isPressed = true
        holdTimer = Timer.scheduledTimer(withTimeInterval: holdThreshold, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isPressed else { return }
                self.isActive = true
                self.onStart()
            }
        }
    }

    private func release() {
        isPressed = false
        holdTimer?.invalidate()
        guard isActive else { return }
        isActive = false
        onStop()
    }
}
