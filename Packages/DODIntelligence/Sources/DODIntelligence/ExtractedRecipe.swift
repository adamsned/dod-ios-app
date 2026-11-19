import Foundation

/// DUT-1026 — ingredients + steps recovered from a post body by the on-device
/// model when both heuristic parse tiers came back empty.
public struct ExtractedRecipe: Sendable, Equatable {
    public let ingredients: [String]
    public let instructions: [String]
    public init(ingredients: [String], instructions: [String]) {
        self.ingredients = ingredients
        self.instructions = instructions
    }
    /// A result with neither list is treated as a failure by callers.
    public var isEmpty: Bool { ingredients.isEmpty && instructions.isEmpty }

    /// Merge per-chunk results in order, dropping blank and exact-duplicate lines.
    public static func merged(_ parts: [ExtractedRecipe]) -> ExtractedRecipe {
        func dedupe(_ lines: [String]) -> [String] {
            var seen = Set<String>()
            return
                lines
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
        }
        return ExtractedRecipe(
            ingredients: dedupe(parts.flatMap(\.ingredients)),
            instructions: dedupe(parts.flatMap(\.instructions))
        )
    }
}

public enum RecipeTextChunker {
    /// Split `text` into chunks of at most `maxCharacters`, breaking on paragraph
    /// boundaries (blank line or newline). A single paragraph longer than the cap is
    /// hard-split. Empty/whitespace input returns [].
    public static func chunks(of text: String, maxCharacters: Int = 4000) -> [String] {
        precondition(maxCharacters > 0)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var result: [String] = []
        var current = ""
        func flush() {
            if !current.isEmpty {
                result.append(current)
                current = ""
            }
        }
        for para in trimmed.components(separatedBy: "\n") where !para.isEmpty {
            var piece = Substring(para)
            while piece.count > maxCharacters {
                flush()
                result.append(String(piece.prefix(maxCharacters)))
                piece = piece.dropFirst(maxCharacters)
            }
            if current.count + piece.count + 1 > maxCharacters { flush() }
            current += current.isEmpty ? String(piece) : "\n" + piece
        }
        flush()
        return result
    }
}
