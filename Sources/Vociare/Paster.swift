import AppKit
import Carbon.HIToolbox

/// Types text into the focused app by pasting it, then puts the previous clipboard back.
@MainActor
enum Paster {
    // Tells clipboard managers to skip this entry (nspasteboard.org convention).
    private static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
    // Password managers mark copied secrets with this type (nspasteboard.org convention).
    private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    static func paste(_ text: String) {
        let text = TextContext.fit(text)
        let pasteboard = NSPasteboard.general
        let saved = (pasteboard.pasteboardItems ?? []).map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in item.data(forType: type).map { (type, $0) } })
        }

        // Keeps the dictated text off Universal Clipboard, which would offer it to the user's other devices.
        pasteboard.prepareForNewContents(with: .currentHostOnly)
        pasteboard.setString(text, forType: .string)
        pasteboard.setData(Data(), forType: transientType)
        let ourChange = pasteboard.changeCount
        pressCommandV()

        // The target app reads the clipboard asynchronously after receiving Cmd+V.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Leave the clipboard alone if the user copied something in the meantime.
            guard pasteboard.changeCount == ourChange else { return }
            pasteboard.clearContents()
            // Putting a password back would stop its password manager from clearing it on schedule.
            guard !saved.contains(where: { $0[concealedType] != nil }) else { return }
            pasteboard.writeObjects(saved.map { contents in
                let item = NSPasteboardItem()
                contents.forEach { item.setData($1, forType: $0) }
                return item
            })
        }
    }

    private static func pressCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        [true, false].forEach { isDown in
            let event = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode(), keyDown: isDown)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
    }

    /// The key that gives Cmd+V in the current layout: on Dvorak or Colemak it isn't the QWERTY V position.
    /// Translating with Command held matches layouts like "Dvorak - QWERTY ⌘", whose shortcuts stay on QWERTY.
    private static func vKeyCode() -> CGKeyCode {
        let fallback = CGKeyCode(kVK_ANSI_V)
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
            let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return fallback }
        let data = Unmanaged<CFData>.fromOpaque(layoutData).takeUnretainedValue() as Data
        return data.withUnsafeBytes { bytes in
            guard let layout = bytes.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return fallback }
            return (0..<128).map(CGKeyCode.init).first { keyCode in
                var deadKeyState: UInt32 = 0
                var length = 0
                var characters = [UniChar](repeating: 0, count: 4)
                let status = UCKeyTranslate(
                    layout, keyCode, UInt16(kUCKeyActionDown), UInt32((cmdKey >> 8) & 0xFF), UInt32(LMGetKbdType()),
                    OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeyState, characters.count, &length, &characters)
                return status == noErr && length == 1 && characters[0] == UniChar(UInt8(ascii: "v"))
            } ?? fallback
        }
    }
}
