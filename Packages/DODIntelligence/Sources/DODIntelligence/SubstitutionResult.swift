import Foundation

/// The outcome of an ingredient-substitution request — richer than a single
/// swap so the model can do the right thing for the dish (US-54 follow-up).
///
/// A plain, FoundationModels-free value type: the on-device model
/// (``LiveDODIntelligenceService``) produces an `@Generable` mirror and maps it
/// onto this, so feature code, view models, tests and snapshots never import
/// FoundationModels. See ``DODIntelligenceService`` for the boundary rationale.
///
/// The three verdicts map to the three things a good cook's assistant can say
/// about a swap:
/// - ``Verdict/options`` — one or more concrete substitutes, best first. The
///   cook picks which one fits (they are not forced to take the first).
/// - ``Verdict/omit`` — the ingredient can reasonably be left out. Useful for
///   optional / non-essential ingredients where no swap is needed.
/// - ``Verdict/notAGoodFit`` — the ingredient is fundamental to the dish, so no
///   substitute keeps it the same recipe (e.g. the green beans in Asian Green
///   Beans). The model is allowed to say "no good substitution" rather than
///   manufacture a nonsensical one.
public struct SubstitutionResult: Sendable, Equatable {

    /// What the assistant concluded. See ``SubstitutionResult`` for when each
    /// applies.
    public enum Verdict: Sendable, Equatable {
        /// One or more concrete substitutes, best first (never empty).
        case options([IngredientSubstitution])
        /// The ingredient can simply be left out; the note says what to expect.
        case omit(note: String)
        /// The ingredient is essential to this dish; the note says why a swap
        /// would change the recipe.
        case notAGoodFit(note: String)
    }

    public let verdict: Verdict

    public init(verdict: Verdict) {
        self.verdict = verdict
    }

    /// Convenience for the common "one or more options" case.
    public static func options(_ options: [IngredientSubstitution]) -> SubstitutionResult {
        SubstitutionResult(verdict: .options(options))
    }
}

extension SubstitutionResult {

    /// Deterministic canned results for ``FakeIntelligenceService``, previews,
    /// and any opt-in L4 snapshot. The live model is non-deterministic and
    /// unavailable in the simulator / CI, so these fixtures are what the per-PR
    /// gates exercise — never the real model.
    public static let cannedButtermilkOptions = SubstitutionResult.options([
        .cannedButtermilk,
        IngredientSubstitution(
            substitute: "1 cup plain yogurt thinned with 2 tbsp water",
            note: "Whisk until pourable, then use cup for cup."
        ),
    ])

    /// Canned "leave it out" result.
    public static let cannedOmit = SubstitutionResult(
        verdict: .omit(note: "This is a garnish here, so you can leave it out without changing the dish.")
    )

    /// Canned "essential ingredient" result.
    public static let cannedNotAGoodFit = SubstitutionResult(
        verdict: .notAGoodFit(
            note: "This ingredient defines the dish, so swapping it would make a different recipe."
        )
    )
}

/// Lightweight recipe context passed alongside a substitution request so the
/// model can weigh the ingredient's ROLE in the actual dish, not just swap
/// "X for Y" in isolation (recipe-aware substitution). Knowing the dish name is
/// often enough for the model to recognise a fundamental ingredient (the green
/// beans in "Asian Green Beans"); the sibling ingredient lines sharpen it.
///
/// Plain value type — no FoundationModels, no persistence coupling.
public struct RecipeContext: Sendable, Equatable {

    /// The source recipe / dish title, e.g. "Asian Green Beans".
    public let recipeTitle: String

    /// Other ingredient lines from the same recipe (excluding the one being
    /// swapped), when known. May be empty.
    public let otherIngredients: [String]

    public init(recipeTitle: String, otherIngredients: [String] = []) {
        self.recipeTitle = recipeTitle
        self.otherIngredients = otherIngredients
    }
}
