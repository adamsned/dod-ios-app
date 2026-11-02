import Foundation

public enum HouseholdDietMatcher {
    /// Soft keyword map: flag -> ingredient substrings that suggest it. Reminder only, not medical-grade.
    static let ingredientKeywords: [DietaryFlag: [String]] = [
        .dairy: ["milk", "butter", "cheese", "cream", "yogurt", "parmesan", "ghee"],
        .gluten: ["flour", "bread", "pasta", "noodle", "breadcrumb", "soy sauce", "tortilla"],
        .nuts: ["almond", "walnut", "pecan", "cashew", "pistachio", "hazelnut"],
        .peanuts: ["peanut"],
        .eggs: ["egg", "mayo"],
        .shellfish: ["shrimp", "crab", "lobster", "clam", "mussel", "scallop"],
        .fish: ["salmon", "cod", "tuna", "anchovy", "tilapia", "fish sauce"],
        .soy: ["soy", "tofu", "edamame", "miso"],
        .pork: ["pork", "bacon", "ham", "sausage", "pancetta", "prosciutto"],
        .vegetarian: ["beef", "chicken", "pork", "bacon", "sausage", "lamb", "turkey", "ham"],
        .vegan: ["beef", "chicken", "pork", "bacon", "milk", "butter", "cheese", "cream", "egg", "honey"],
    ]

    /// Diet tokens in `Recipe.suitableForDiet` (after URL prettify, lowercased) that PROVE a recipe is safe for a flag.
    static let safeDietTokens: [DietaryFlag: [String]] = [
        .dairy: ["dairyfree", "vegan"], .gluten: ["glutenfree"],
        .vegetarian: ["vegetarian", "vegan"], .vegan: ["vegan"],
    ]

    /// Returns the flags (from `flags`) that `ingredientTexts` trip. A flag whose safe diet token appears in `diets` is skipped.
    public static func triggeredFlags(
        flags: Set<DietaryFlag>,
        ingredientTexts: [String],
        diets: [String]
    ) -> Set<DietaryFlag> {
        let dietText = diets.joined(separator: " ").lowercased()
        let lines = ingredientTexts.map { $0.lowercased() }
        var hit: Set<DietaryFlag> = []
        for flag in flags {
            if let safe = safeDietTokens[flag], safe.contains(where: { dietText.contains($0) }) { continue }
            let words = ingredientKeywords[flag] ?? []
            if lines.contains(where: { line in words.contains(where: { line.contains($0) }) }) { hit.insert(flag) }
        }
        return hit
    }
}
