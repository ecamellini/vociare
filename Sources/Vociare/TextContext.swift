import AppKit
import NaturalLanguage
import OSLog

/// Fits a dictation to the text around the cursor: the model writes a whole sentence (capital, full stop, no
/// spaces around it), which glues to the previous word or capitalizes mid-sentence.
@MainActor
enum TextContext {
    private static let logger = Logger(subsystem: "me.ecamel.vociare", category: "TextContext")
    // Enough to see past a few spaces back to the last word or punctuation.
    private static let lookBehind = 8

    /// Reads the focused field with the Accessibility API. Where it exposes nothing (terminals, some Electron
    /// apps), a trailing space keeps the next dictation apart.
    static func fit(_ text: String) -> String {
        let app = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "?"
        guard let (before, after) = around() else {
            logger.notice("No text context in \(app, privacy: .public): adding a trailing space")
            return text + " "
        }
        logger.notice(
            "Pasting in \(app, privacy: .public) after \(kind(before.last), privacy: .public), before \(kind(after.first), privacy: .public)")
        return fit(text, before: before, after: after, names: Replacements.words)
    }

    /// `before` ends at the cursor (empty at the start of the field), `after` starts there. `names` keep their capital.
    static func fit(_ text: String, before: String, after: String, names: Set<String>) -> String {
        guard let first = text.first else { return text }
        var text = text
        // Mid-sentence: after a word or a comma, not after a full stop or at the start of a line.
        let previous = before.reversed().first { !$0.isWhitespace || $0.isNewline }
        if let previous, !previous.isNewline, !".!?…".contains(previous), first.isUppercase, !keepsCapital(text, names: names) {
            text = first.lowercased() + text.dropFirst()
        }
        if let last = before.last, last.isLetter || last.isNumber || ".,;:!?)]}»”…%".contains(last) { text = " " + text }
        if let next = after.first, next.isLetter || next.isNumber { text += " " }
        return text
    }

    /// Names, acronyms and "I" keep their capital; a word only known capitalized is a name too ("Milano").
    private static func keepsCapital(_ text: String, names: Set<String>) -> Bool {
        let word = String(text.prefix { $0.isLetter })
        if word.isEmpty || word == "I" || names.contains(word) || (word.count > 1 && word == word.uppercased()) { return true }
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        let tag = tagger.tag(at: text.startIndex, unit: .word, scheme: .nameType).0
        if [.personalName, .placeName, .organizationName].contains(tag) { return true }
        let language = NLLanguageRecognizer.dominantLanguage(for: text)?.rawValue
        let misspelled = NSSpellChecker.shared.checkSpelling(
            of: word.lowercased(), startingAt: 0, language: language, wrap: false, inSpellDocumentWithTag: 0, wordCount: nil)
        return misspelled.location != NSNotFound
    }

    /// The text just before the cursor (or the selection it replaces) and the character after it.
    private static func around() -> (before: String, after: String)? {
        let system = AXUIElementCreateSystemWide()
        // On the system-wide element it applies to every call: a hung app mustn't hold up the paste.
        AXUIElementSetMessagingTimeout(system, 0.2)
        guard let focused = attribute(system, kAXFocusedUIElementAttribute), CFGetTypeID(focused) == AXUIElementGetTypeID()
        else { return nil }
        let element = focused as! AXUIElement
        var range = CFRange()
        guard let value = attribute(element, kAXSelectedTextRangeAttribute), CFGetTypeID(value) == AXValueGetTypeID(),
            AXValueGetValue(value as! AXValue, .cfRange, &range)
        else { return nil }
        let start = max(0, range.location - lookBehind)
        guard let before = string(element, from: start, length: range.location - start) else { return nil }
        // Past the end of the text some apps answer with an error rather than an empty string.
        return (before, string(element, from: range.location + range.length, length: 1) ?? "")
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }

    private static func string(_ element: AXUIElement, from location: Int, length: Int) -> String? {
        guard length > 0 else { return "" }
        var range = CFRange(location: location, length: length)
        guard let parameter = AXValueCreate(.cfRange, &range) else { return nil }
        var value: CFTypeRef?
        let status = AXUIElementCopyParameterizedAttributeValue(
            element, kAXStringForRangeParameterizedAttribute as CFString, parameter, &value)
        return status == .success ? value as? String : nil
    }

    /// For the log, which never holds the text itself.
    private static func kind(_ character: Character?) -> String {
        guard let character else { return "nothing" }
        if character.isNewline { return "a line break" }
        if character.isWhitespace { return "a space" }
        if character.isLetter || character.isNumber { return "a word" }
        return "punctuation"
    }
}
