import Foundation

/// DUT-1021 — plain result of an "Explain This Step" request.
public struct StepExplanation: Sendable, Equatable {
    public let expandedText: String
    public let whyItMatters: String
    public let commonMistake: String

    public init(expandedText: String, whyItMatters: String, commonMistake: String) {
        self.expandedText = expandedText
        self.whyItMatters = whyItMatters
        self.commonMistake = commonMistake
    }

    public static let canned = StepExplanation(
        expandedText: "Gently combine so you don't deflate the air that makes it rise.",
        whyItMatters: "Trapped air is what lifts the batter.",
        commonMistake: "Stirring hard, which knocks the air out."
    )
}

extension StepExplanation {
    /// Numbers that carry a unit (temperature or time) in `text`, e.g. "350°F", "20 minutes", "10 min".
    /// Returned lowercased with spaces removed, so "20 Minutes" -> "20minutes".
    static func quantities(in text: String) -> Set<String> {
        let pattern = #"\d+(?:\.\d+)?\s*(?:°\s*[fc]?|degrees|minutes?|mins?|hours?|hrs?|seconds?|secs?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return Set(
            regex.matches(in: text, range: range).compactMap { match in
                Range(match.range, in: text).map { text[$0].lowercased().filter { !$0.isWhitespace } }
            }
        )
    }

    /// `true` when every temperature/time quantity in the explanation also appears in `source`
    /// (the original step text). Grounding guard: a rephrase must not invent specifics.
    public func isGrounded(in source: String) -> Bool {
        let allowed = Self.quantities(in: source)
        let produced = Self.quantities(in: [expandedText, whyItMatters, commonMistake].joined(separator: " "))
        return produced.isSubset(of: allowed)
    }
}
