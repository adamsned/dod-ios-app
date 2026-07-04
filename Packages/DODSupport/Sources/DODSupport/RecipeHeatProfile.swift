import DODDomain
import Foundation

/// Pure, dependency-free derivation of a recipe's **heat profile** — the oven
/// temperature and the cooking task — read straight from the recipe's own
/// free-text steps and title. It answers "what does this recipe want the oven
/// to do?" so a surface (the per-recipe Heat Coach nudge) can hand those two
/// values to ``CharcoalRecipeConverter/recommend(ovenTempF:ovenDiameterInches:task:)``
/// and show a starting coal count.
///
/// **Confidence gate.** ``derive(from:)`` returns `nil` when no explicit-unit
/// temperature can be found anywhere in the recipe. A `nil` result is the
/// caller's signal to *hide the nudge* rather than guess — the app never
/// fabricates an oven temperature. When a temperature is present but no task
/// keyword matches, the task falls back to ``CharcoalRecipeConverter/CookTask/bake``
/// (First Cookout's baseline), never `nil`.
///
/// **Why the max temperature.** A recipe often mentions several temperatures
/// (a preheat, a sear, a finish). The primary oven temperature is the highest
/// explicit-unit value across every step (and the title), matching how a cook
/// sets the dial for the hottest part of the cook. Ranges contribute both ends
/// via ``TemperatureConverter/fahrenheitValues(in:)``, so `350-375°F` yields
/// `375` as its high end.
///
/// Why this lives in `DODSupport` (not a feature package): like
/// ``CharcoalRecipeConverter`` and ``TemperatureConverter`` it is a pure,
/// Foundation-only value transform with no UI dependency, `Sendable`-friendly
/// and I/O-free, so the recipe card, Cook Mode, and any future surface can
/// reuse the same contract without a cross-package dependency.
///
/// Spec trace: DUT-551 (Cooking Tools hub) Stream D. CL-306.
public enum RecipeHeatProfile {

    /// A recipe's derived heat profile: the primary oven temperature in °F and
    /// the inferred ``CharcoalRecipeConverter/CookTask``. Oven diameter is
    /// deliberately absent — the caller supplies it (12" by default, matching
    /// the Heat Coach) when it runs the charcoal recommendation.
    public struct Derived: Equatable, Sendable {
        /// The primary (maximum explicit-unit) oven temperature, in °F.
        public let ovenTempF: Int
        /// The cooking task inferred from title + step keywords.
        public let task: CharcoalRecipeConverter.CookTask

        public init(ovenTempF: Int, task: CharcoalRecipeConverter.CookTask) {
            self.ovenTempF = ovenTempF
            self.task = task
        }
    }

    /// Derive a ``Derived`` heat profile from `recipe`, or `nil` when the
    /// recipe carries no explicit-unit temperature (the caller then hides the
    /// nudge — see the confidence gate above).
    ///
    /// - Temperature: the maximum °F across every `instructions[].text` and the
    ///   `title`, via ``TemperatureConverter/fahrenheitValues(in:)``. No value
    ///   found → `nil`.
    /// - Task: keyword inference over the title + step text (see
    ///   ``inferTask(title:instructions:)``), defaulting to `.bake`.
    public static func derive(from recipe: Recipe) -> Derived? {
        let stepTexts = recipe.instructions.map(\.text)
        let searchTexts = stepTexts + [recipe.title]

        let temperatures = searchTexts.flatMap { TemperatureConverter.fahrenheitValues(in: $0) }
        guard let ovenTempF = temperatures.max() else {
            // No explicit-unit temperature anywhere — not confident, hide the nudge.
            return nil
        }

        let task = inferTask(title: recipe.title, instructions: stepTexts)
        return Derived(ovenTempF: ovenTempF, task: task)
    }

    // MARK: - Task inference

    /// Ordered keyword table mapping cook-method language to a
    /// ``CharcoalRecipeConverter/CookTask``. Order matters: the first group
    /// whose keyword appears wins, so more specific/decisive methods (searing,
    /// simmering) are checked before the broad bake bucket. Keywords are
    /// matched case-insensitively as substrings of the combined title + steps.
    private static let taskKeywords: [(task: CharcoalRecipeConverter.CookTask, keywords: [String])] = [
        // Direct bottom heat — searing / frying.
        (.fry, ["sear", "fry", "fried", "deep-fry", "pan-fry"]),
        // Bottom-led gentle heat — stews, beans, sauces held low.
        (.simmer, ["stew", "beans", "chili", "soup", "simmer", "braise", "braised", "sauce"]),
        // Even all-around heat — whole birds and roasts.
        (.roast, ["roast", "whole chicken", "whole turkey", "turkey", "prime rib"]),
        // Lid-heavy heat — breads, cakes, cobblers, casseroles, biscuits.
        (.bake, ["bread", "cake", "cobbler", "casserole", "biscuit", "muffin", "bake", "baked", "baking"]),
    ]

    /// Infer the cooking task from the recipe's title + step text. Returns the
    /// first keyword group that matches (in ``taskKeywords`` order), or
    /// ``CharcoalRecipeConverter/CookTask/bake`` when a temperature is present
    /// but no keyword lands — the same lid-heavy baseline First Cookout uses.
    static func inferTask(
        title: String,
        instructions: [String]
    ) -> CharcoalRecipeConverter.CookTask {
        let haystack = ([title] + instructions).joined(separator: " ").lowercased()
        for entry in taskKeywords where entry.keywords.contains(where: haystack.contains) {
            return entry.task
        }
        return .bake
    }
}
