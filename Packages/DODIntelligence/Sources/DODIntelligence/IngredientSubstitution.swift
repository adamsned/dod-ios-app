import Foundation

/// A single ingredient-substitution suggestion, as consumed by feature code.
///
/// This is a plain, FoundationModels-free value type. The on-device model
/// (``LiveDODIntelligenceService``) produces an `@Generable` mirror of this
/// shape and maps it onto this struct, so callers, view models, tests, and
/// snapshots never import (or link against) FoundationModels — which is
/// iOS-26-only and unavailable on the macOS `swift test` slice. See
/// ``DODIntelligenceService`` for the boundary rationale.
public struct IngredientSubstitution: Sendable, Equatable {

    /// The substitute ingredient and amount, e.g.
    /// `"1 cup milk + 1 tbsp lemon juice"`.
    public let substitute: String

    /// One short sentence on how to use the substitute.
    public let note: String

    public init(substitute: String, note: String) {
        self.substitute = substitute
        self.note = note
    }
}

extension IngredientSubstitution {

    /// A deterministic canned suggestion used by ``FakeIntelligenceService`` for
    /// L1 tests and any (opt-in) L4 snapshot. The live on-device model is
    /// non-deterministic AND unavailable in the simulator / CI, so the fake +
    /// this fixture are what the per-PR gates exercise — never the real model.
    public static let cannedButtermilk = IngredientSubstitution(
        substitute: "1 cup milk + 1 tbsp lemon juice",
        note: "Stir and let it sit five minutes until it thickens, then use as buttermilk."
    )
}
