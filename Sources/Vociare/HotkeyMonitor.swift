import AppKit
import Carbon.HIToolbox
import OSLog

/// The key held to dictate: a right-hand modifier, which types nothing when held alone.
enum DictationKey: String, CaseIterable {
    case rightCommand, rightOption, rightControl

    var name: String {
        switch self {
        case .rightCommand: "right ⌘"
        case .rightOption: "right ⌥"
        case .rightControl: "right ⌃"
        }
    }

    var menuTitle: String {
        switch self {
        case .rightCommand: "Right Command"
        case .rightOption: "Right Option"
        case .rightControl: "Right Control"
        }
    }

    fileprivate var keyCode: Int {
        switch self {
        case .rightCommand: kVK_RightCommand
        case .rightOption: kVK_RightOption
        case .rightControl: kVK_RightControl
        }
    }

    // Device-dependent flags, which tell the right key from the left one.
    fileprivate var mask: UInt64 {
        switch self {
        case .rightCommand: 0x10  // NX_DEVICERCMDKEYMASK
        case .rightOption: 0x40  // NX_DEVICERALTKEYMASK
        case .rightControl: 0x2000  // NX_DEVICERCTLKEYMASK
        }
    }
}

/// Reports long presses of the dictation key, and Esc during one. A short tap, a modifier+key combo or a
/// modifier+click stays a normal one.
@MainActor
final class HotkeyMonitor {
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

    var key: DictationKey = .rightCommand {
        didSet {
            // The old key's release would never arrive: drop its press, and any dictation it started.
            holdTimer?.invalidate()
            isPressed = false
            if isActive {
                isActive = false
                onCancel()
            }
        }
    }

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
        logger.notice("Listening for the dictation key")
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
        case .flagsChanged where event.getIntegerValueField(.keyboardEventKeycode) == key.keyCode:
            let pressed = event.flags.rawValue & key.mask != 0
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
