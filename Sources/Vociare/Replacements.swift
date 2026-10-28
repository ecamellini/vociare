import Foundation
import OSLog

/// Rewrites what the model gets wrong, from rules the user keeps in a text file: Parakeet can't be given a
/// vocabulary. The file is read at every dictation, so edits apply without a relaunch.
enum Replacements {
    struct Rule {
        let pattern: NSRegularExpression
        let replacement: String
    }

    private static let logger = Logger(subsystem: "me.ecamel.vociare", category: "Replacements")

    static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Vociare/replacements.txt")
    }

    static let template = """
        # One rule per line: what the model writes, comma-separated, then -> and the right text.
        # Case-insensitive, whole words only, applied from top to bottom. For example:
        # cloud code, claud code -> Claude Code

        """

    static func apply(to text: String) -> String {
        guard let file = try? String(contentsOf: url, encoding: .utf8) else { return text }
        return apply(rules(from: file), to: text)
    }

    static func apply(_ rules: [Rule], to text: String) -> String {
        rules.reduce(text) { text, rule in
            rule.pattern.stringByReplacingMatches(
                in: text, range: NSRange(text.startIndex..., in: text),
                withTemplate: NSRegularExpression.escapedTemplate(for: rule.replacement))
        }
    }

    static func rules(from file: String) -> [Rule] {
        file.components(separatedBy: .newlines).enumerated().compactMap { index, line in
            let line = line.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { return nil }
            let sides = line.components(separatedBy: "->")
            let variants = sides[0].split(separator: ",").map { $0.split(whereSeparator: \.isWhitespace) }
                .filter { !$0.isEmpty }
            let replacement = sides.count == 2 ? sides[1].trimmingCharacters(in: .whitespaces) : ""
            guard !variants.isEmpty, !replacement.isEmpty else {
                logger.error("Skipped line \(index + 1, privacy: .public) of the replacements: not \"variant, variant -> text\"")
                return nil
            }
            // Longest first, so "claud code" wins over "claud" in the same rule; any run of spaces matches a space.
            let alternatives = variants.sorted { $0.joined(separator: " ").count > $1.joined(separator: " ").count }
                .map { $0.map { NSRegularExpression.escapedPattern(for: String($0)) }.joined(separator: "\\s+") }
            let pattern = "(?<![\\p{L}\\p{N}])(?:" + alternatives.joined(separator: "|") + ")(?![\\p{L}\\p{N}])"
            // Every variant is escaped, so the pattern always compiles.
            return Rule(pattern: try! NSRegularExpression(pattern: pattern, options: .caseInsensitive), replacement: replacement)
        }
    }
}
