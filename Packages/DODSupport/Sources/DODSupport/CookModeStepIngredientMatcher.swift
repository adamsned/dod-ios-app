import Foundation

/// DUT-116 — which ingredient lines a step's text refers to.
public enum CookModeStepIngredientMatcher {

    private static let noise: Set<String> = [
        "cup", "cups", "teaspoon", "teaspoons", "tablespoon", "tablespoons",
        "ounce", "ounces", "pound", "pounds", "chopped", "diced", "minced",
        "sliced", "fresh", "large", "small", "medium", "finely", "freshly",
        "ground", "whole", "divided", "optional", "taste", "more", "plus",
    ]

    /// Ingredient lines (original text, original order) with at least one
    /// significant word (letters only, 4+ chars, not in `noise`) that appears as a
    /// whole word in `stepText`, case-insensitively.
    public static func matching(stepText: String, ingredients: [String]) -> [String] {
        let stepWords = Set(words(in: stepText))
        return ingredients.filter { line in
            words(in: line).contains { $0.count >= 4 && !noise.contains($0) && stepWords.contains($0) }
        }
    }

    private static func words(in text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz").inverted)
            .filter { !$0.isEmpty }
    }
}
