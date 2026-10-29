import DODDomain
import DODIntelligence
import DODSupport
import Foundation
import Observation

// Split out of `ShoppingListViewModel.swift` to keep it under SwiftLint's
// `file_length` cap.

// MARK: - Construction from recipes

extension ShoppingListViewModel {

    /// Build a view-model from recipes, exploding each recipe's ingredients
    /// into per-recipe rows classified by ``IngredientAisleClassifier``
    /// (CL-77 — no cross-recipe merge). This is the shape T-680c's production
    /// initializer reuses once the entry surfaces feed real recipes in. Takes
    /// the exploded rows AS-IS through ``init(items:store:)`` (DUT-488) — it is
    /// NOT auto-loaded, so an explicit recipe build is never clobbered by a
    /// saved list. `store` defaults to the real App-Group store; pass `nil` to
    /// build in memory only.
    public convenience init(
        recipes: [Recipe],
        store: ShoppingListStore? = ShoppingListStore(),
        intelligence: (any DODIntelligenceService)? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.init(
            items: Self.applyMetricPreference(Self.rows(from: recipes), defaults: defaults),
            store: store,
            intelligence: intelligence,
            defaults: defaults
        )
    }

    /// Explode `recipes` into per-recipe ``Item`` rows, each classified through
    /// ``IngredientAisleClassifier`` (CL-77 — no cross-recipe merge). Shared by
    /// ``init(recipes:)`` and ``add(recipes:)`` (DUT-487 / T-906) so the initial
    /// build and later appends produce identical rows. DUT-534 — module-internal
    /// (was `private`) so ``LiveShoppingListAppender`` builds the exact same rows
    /// when appending from Recipe Detail / a card, rather than duplicating the
    /// explode-and-classify logic.
    static func rows(from recipes: [Recipe]) -> [Item] {
        recipes.flatMap { recipe in
            recipe.ingredients.compactMap { ingredient -> Item? in
                // Defense-in-depth (DUT-587): drop any ingredient whose text
                // trims to empty so a blank/whitespace line — even one that
                // slips past the parser — never becomes a garbage row.
                guard
                    !ingredient.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else {
                    return nil
                }
                return Item(
                    ingredientText: ingredient.text,
                    recipeTitle: recipe.title,
                    aisle: IngredientAisleClassifier.classify(ingredient.text)
                )
            }
        }
    }

    // The append de-dup lives in `+Dedup`, the metric-preference rewrite in
    // `+MetricPreference`, and the CL-82 mock fixture in `+Mock`.
}
