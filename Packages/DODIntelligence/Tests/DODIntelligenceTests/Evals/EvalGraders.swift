import Foundation

/// Deterministic graders for free-text model output. Each returns an array of
/// failure strings (empty means pass), matching the eval `grade` closure shape.
enum EvalGraders {

    /// Fails if `text` is empty or whitespace-only.
    static func nonEmpty(_ text: String?) -> [String] {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ["output is empty"]
        }
        return []
    }

    /// Fails for each phrase (case-insensitive) that appears in `text`.
    /// Use for unsafe absolutes such as "definitely safe to eat" or "guaranteed done".
    static func forbids(_ phrases: [String], in text: String) -> [String] {
        let lower = text.lowercased()
        return phrases.filter { lower.contains($0.lowercased()) }
            .map { "contains forbidden phrase '\($0)'" }
    }

    /// Fails unless at least one of `anyOf` appears (case-insensitive).
    /// Use for safety framing such as ["thermometer", "internal temperature", "check"].
    static func requiresAny(_ anyOf: [String], in text: String) -> [String] {
        let lower = text.lowercased()
        return anyOf.contains { lower.contains($0.lowercased()) }
            ? [] : ["missing any of \(anyOf)"]
    }

    /// All integers that appear in `text`, in order ("use 24 coals, 12 on top" -> [24, 12]).
    static func integers(in text: String) -> [Int] {
        text.split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
    }

    /// Fails for each integer in `text` that is not in `allowed`.
    /// This catches hallucinated numbers such as coal counts.
    static func numbersGrounded(in text: String, allowed: Set<Int>) -> [String] {
        integers(in: text).filter { !allowed.contains($0) }
            .map { "ungrounded number \($0)" }
    }
}
