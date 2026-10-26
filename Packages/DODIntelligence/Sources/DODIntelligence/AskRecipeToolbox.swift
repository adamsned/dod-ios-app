import Foundation

/// DUT-1028 — pure, FoundationModels-free recipe slices for Ask-The-Recipe tools.
public struct AskRecipeToolbox: Sendable, Equatable {
    public let title: String
    public let servings: Int?
    /// Already scaled by the caller via FractionRenderer.scale (same path as the ingredients list).
    public let scaledIngredients: [String]
    public let steps: [String]

    public init(title: String, servings: Int?, scaledIngredients: [String], steps: [String]) {
        self.title = title
        self.servings = servings
        self.scaledIngredients = scaledIngredients
        self.steps = steps
    }

    /// Ingredient lines containing `keyword` (case-insensitive); empty keyword returns all, capped at 12.
    public func ingredients(matching keyword: String) -> [String] {
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hits =
            trimmedKeyword.isEmpty
            ? scaledIngredients : scaledIngredients.filter { $0.lowercased().contains(trimmedKeyword) }
        return Array(hits.prefix(12))
    }

    /// 1-based step text; nil when out of range.
    public func step(number: Int) -> String? {
        guard number >= 1, number <= steps.count else { return nil }
        return steps[number - 1]
    }

    /// Steps whose text contains `keyword` as "N. text", capped at 5 (e.g. 'cool', 'refrigerate', 'rest').
    public func steps(matching keyword: String) -> [String] {
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedKeyword.isEmpty else { return [] }
        return steps.enumerated()
            .filter { $0.element.lowercased().contains(trimmedKeyword) }
            .prefix(5)
            .map { "\($0.offset + 1). \($0.element)" }
    }
}
