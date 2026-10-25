import DODDomain
import Foundation

/// DUT-168 — matches Cook Mode step text against the recipe's ingredient lines.
enum StepIngredientMatcher {

    /// Quantity / unit / filler words stripped from an ingredient line to get its name.
    private static let noise: Set<String> = [
        "cup", "cups", "tbsp", "tsp", "tablespoon", "tablespoons", "teaspoon", "teaspoons",
        "oz", "ounce", "ounces", "lb", "lbs", "pound", "pounds", "g", "kg", "ml", "l",
        "pinch", "dash", "clove", "cloves", "can", "cans", "large", "small", "medium",
        "of", "a", "an", "the", "to", "taste", "fresh", "chopped", "diced", "minced",
        "melted", "softened", "optional", "and", "or",
    ]

    /// Lowercased, singularised name words of an ingredient line (digits, fractions, noise dropped).
    static func nameWords(of ingredientText: String) -> [String] {
        let lowered = ingredientText.lowercased()
        let parts = lowered.split { !($0.isLetter) }.map(String.init)
        return parts.filter { $0.count > 2 && !noise.contains($0) }.map(singular)
    }

    private static func singular(_ word: String) -> String {
        if word.hasSuffix("ies"), word.count > 4 { return String(word.dropLast(3)) + "y" }
        if word.hasSuffix("s"), !word.hasSuffix("ss"), word.count > 3 { return String(word.dropLast()) }
        return word
    }

    /// Ingredients (in recipe order) whose name words ALL appear as whole words in `stepText`.
    static func matches(stepText: String, ingredients: [RecipeIngredient]) -> [RecipeIngredient] {
        let stepWords = Set(
            stepText.lowercased().split { !$0.isLetter }.map(String.init).map(singular)
        )
        return ingredients.filter { ingredient in
            let words = nameWords(of: ingredient.text)
            return !words.isEmpty && words.allSatisfy(stepWords.contains)
        }
    }

    /// One entry per instruction, index-aligned with `instructions`.
    static func mapping(
        instructions: [RecipeInstruction],
        ingredients: [RecipeIngredient]
    ) -> [[RecipeIngredient]] {
        instructions.map { matches(stepText: $0.text, ingredients: ingredients) }
    }
}
