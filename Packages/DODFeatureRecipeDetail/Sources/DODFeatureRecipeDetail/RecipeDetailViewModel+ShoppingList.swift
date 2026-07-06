import DODDomain
import DODSupport
import Foundation

// DUT-534 — "Add to Shopping List from any recipe". The Recipe-Detail toolbar
// action. Split into its own extension file to keep `RecipeDetailViewModel.swift`
// under the SwiftLint 400-line `file_length` cap (matches the `+Download` /
// `+Servings` / `+CommentSubmit` splits).

extension RecipeDetailViewModel {

    /// Append the currently-loaded recipe's ingredients to the Shopping List,
    /// then surface a confirming Snackbar. Detail already carries a fully-loaded
    /// `recipe`, so no hydration is needed — the appender skips the fetch.
    ///
    /// - `.added(count:)` → "Added N ingredients to your Shopping List" with a
    ///   trailing **View** action (the view routes it to `dod://shopping-list`).
    /// - `.couldntLoad` (no recipe yet, or the append seam isn't wired) →
    ///   "Couldn't load ingredients — open the recipe to add." with no action.
    ///
    /// Wraps the existing snackbar machinery: setting `snackbarMessage` shows
    /// the toast, and `snackbarActionTitle` drives the optional button; the
    /// view's `.task` auto-dismisses both after a few seconds (DUT-419).
    ///
    /// DUT-639 — the appended rows are the SCALED (and, when the user has
    /// "Use Metric Units" on, metric-converted) ingredient lines, matching what
    /// the ingredients list shows and what Cook Mode carries. `useMetric` is the
    /// AppStorage preference the view reads; the toolbar direct-add path passes
    /// it in so a recipe scaled to 2× lands "4 cups", not the raw "2 cups".
    public func addToShoppingList(useMetric: Bool = false) async {
        guard let recipe else {
            showAddToShoppingListSnackbar(for: .couldntLoad)
            return
        }
        let scaled = Self.scaledRecipe(recipe, by: servingsScaleFactor, useMetric: useMetric)
        let result = await dependencies.addToShoppingList(scaled)
        showAddToShoppingListSnackbar(for: result)
    }

    /// DUT-639 — return a copy of `recipe` whose ingredient `text` values are
    /// scaled by `factor` and (when `useMetric`) metric-converted, using the
    /// SAME pipeline the ingredients list + Cook Mode use for display
    /// (`FractionRenderer.scale` then `IngredientMetricConverter.metric`, in
    /// that order — the converter reads the post-scale quantity). Everything
    /// else on the recipe is carried through unchanged. A no-op factor of `1.0`
    /// with metric off still round-trips the text through `FractionRenderer`,
    /// which returns non-quantity lines untouched. Pure + `nonisolated static`
    /// so it's unit-testable without spinning up the view model.
    nonisolated static func scaledRecipe(
        _ recipe: Recipe,
        by factor: Double,
        useMetric: Bool
    ) -> Recipe {
        let scaledIngredients = recipe.ingredients.map { ingredient -> RecipeIngredient in
            let scaled = FractionRenderer.scale(ingredient.text, by: factor)
            let text = useMetric ? IngredientMetricConverter.metric(scaled) : scaled
            return RecipeIngredient(id: ingredient.id, text: text)
        }
        return Recipe(
            id: recipe.id,
            slug: recipe.slug,
            title: recipe.title,
            excerpt: recipe.excerpt,
            canonicalURL: recipe.canonicalURL,
            heroImage: recipe.heroImage,
            heroImageLargeURL: recipe.heroImageLargeURL,
            categoryIDs: recipe.categoryIDs,
            publishedAt: recipe.publishedAt,
            ingredients: scaledIngredients,
            instructions: recipe.instructions,
            prepTime: recipe.prepTime,
            cookTime: recipe.cookTime,
            totalTime: recipe.totalTime,
            servings: recipe.servings,
            nutrition: recipe.nutrition,
            video: recipe.video,
            kind: recipe.kind,
            articleBodyHTML: recipe.articleBodyHTML,
            recipeCategory: recipe.recipeCategory,
            recipeCuisine: recipe.recipeCuisine,
            suitableForDiet: recipe.suitableForDiet,
            author: recipe.author
        )
    }

    /// Map an ``AddToShoppingListResult`` onto the Snackbar copy + optional
    /// action. Pure state mutation — the view renders it. DUT-535 — `internal`
    /// (was `private`) so ``RecipeDetailView`` calls it from the selection
    /// sheet's completion after the chosen subset is appended.
    func showAddToShoppingListSnackbar(for result: AddToShoppingListResult) {
        switch result {
        case .added(let count):
            snackbarMessage = Self.addedMessage(count: count)
            snackbarActionTitle = "View"
        case .couldntLoad:
            snackbarMessage = "Couldn't load ingredients — open the recipe to add."
            snackbarActionTitle = nil
        }
    }

    /// "Added N ingredient(s) to your Shopping List" — singular/plural aware.
    /// `nonisolated static` + pure so it's unit-testable without the view model.
    nonisolated static func addedMessage(count: Int) -> String {
        let noun = count == 1 ? "ingredient" : "ingredients"
        return "Added \(count) \(noun) to your Shopping List"
    }
}
