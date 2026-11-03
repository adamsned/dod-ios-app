public enum RecipeDietEvaluator {
    static let allergenKeywords: [Allergen: [String]] = [
        .nuts: ["almond", "walnut", "pecan", "cashew", "pistachio", "hazelnut", "peanut"],
        .shellfish: ["shrimp", "crab", "lobster", "clam", "oyster", "scallop", "mussel"],
        .eggs: ["egg", "mayonnaise"],
        .dairy: ["milk", "butter", "cheese", "cream", "yogurt", "buttermilk"],
        .gluten: ["flour", "bread", "pasta", "noodle", "breadcrumb", "biscuit", "cracker"],
        .soy: ["soy", "tofu", "edamame", "miso"],
        .fish: ["salmon", "tuna", "cod", "anchovy", "trout", "catfish"],
    ]

    static let patternViolations: [DietaryPattern: [String]] = [
        .vegetarian: [
            "beef", "pork", "chicken", "bacon", "sausage", "ham", "turkey", "lamb", "shrimp", "fish",
        ],
        .vegan: [
            "beef", "pork", "chicken", "bacon", "sausage", "ham", "turkey", "lamb", "shrimp", "fish",
            "milk", "butter", "cheese", "cream", "egg", "honey",
        ],
        .glutenFree: ["flour", "bread", "pasta", "noodle", "breadcrumb", "biscuit"],
        .dairyFree: ["milk", "butter", "cheese", "cream", "yogurt"],
        .keto: ["sugar", "flour", "pasta", "rice", "potato", "bread"],
        .lowSodium: [],
    ]

    /// True when any line contains any of the words (callers pass lowercased lines).
    static func matches(_ lines: [String], anyOf words: [String]) -> Bool {
        lines.contains { line in words.contains { line.contains($0) } }
    }

    /// The flagged allergens whose keywords appear in any ingredient line.
    static func allergenHits(in lines: [String], for allergens: Set<Allergen>) -> Set<Allergen> {
        allergens.filter { matches(lines, anyOf: allergenKeywords[$0] ?? []) }
    }
}
