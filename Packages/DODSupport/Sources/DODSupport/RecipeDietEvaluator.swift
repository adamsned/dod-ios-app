import DODDomain

public struct DietEvaluation: Sendable, Equatable {
    /// Flagged allergens found in the ingredient text.
    public let allergenHits: Set<Allergen>
    /// True when every selected pattern is affirmed by `suitableForDiet` or by no violating ingredient.
    public let fitsDiet: Bool
    /// True when the recipe has no ingredient data, so no safety claim can be made.
    public let isIncomplete: Bool
}

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

    /// `declared` is `Recipe.suitableForDiet` lowercased.
    static func declaresLowSodium(_ declared: [String]) -> Bool {
        declared.contains { $0.contains("lowsalt") || $0.contains("lowsodium") }
    }

    /// True when the profile selects patterns and every one is affirmed.
    static func fitsPatterns(
        _ patterns: Set<DietaryPattern>,
        lines: [String],
        declared: [String]
    ) -> Bool {
        guard !patterns.isEmpty else { return false }
        return patterns.allSatisfy { pattern in
            if pattern == .lowSodium { return declaresLowSodium(declared) }
            if lines.isEmpty { return false }
            return !matches(lines, anyOf: patternViolations[pattern] ?? [])
        }
    }

    public static func evaluate(_ recipe: Recipe, against profile: DietaryProfile) -> DietEvaluation {
        let lines = recipe.ingredients.map { $0.text.lowercased() }
        let declared = recipe.suitableForDiet.map { $0.lowercased() }
        let incomplete = lines.isEmpty
        let fits = fitsPatterns(profile.patterns, lines: lines, declared: declared)
        return DietEvaluation(
            allergenHits: allergenHits(in: lines, for: profile.allergens),
            fitsDiet: fits && !incomplete,
            isIncomplete: incomplete
        )
    }

    /// Filter used by the opt-in toggle. An empty profile or a disabled toggle returns the input unchanged.
    /// Recipes with allergen hits are dropped. Recipes with incomplete data are dropped when allergens are flagged.
    public static func filter(_ recipes: [Recipe], profile: DietaryProfile) -> [Recipe] {
        guard profile.onlyShowFitting, !profile.isEmpty else { return recipes }
        return recipes.filter { recipe in
            let result = evaluate(recipe, against: profile)
            if !result.allergenHits.isEmpty { return false }
            if !profile.allergens.isEmpty && result.isIncomplete { return false }
            return profile.patterns.isEmpty || result.fitsDiet
        }
    }
}
