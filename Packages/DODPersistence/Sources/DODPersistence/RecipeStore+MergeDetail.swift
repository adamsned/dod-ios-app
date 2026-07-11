import DODDomain
import Foundation

extension RecipeStore {

    /// Shared, default-config `JSONEncoder` reused by the detail-persist paths
    /// below — a default `JSONEncoder` is safe to reuse across encode calls, so
    /// this avoids allocating a fresh encoder per blob field on every
    /// `mergeDetail` (fired on every recipe open/refresh). Mirrors the shared
    /// ``sharedDecoder`` on the read path. DUT-694.
    private static let encoder = JSONEncoder()

    /// Shared, read-only `JSONDecoder` for ``indexIngredients(from:)`` —
    /// mirrors ``encoder`` above (safe to reuse across decode calls).
    private static let decoder = JSONDecoder()

    /// DUT-592 follow-up (US-12 / DUT-11): the ingredients to feed the
    /// `CachedIngredient` search index after a merge, decoded from what
    /// actually landed on `target.ingredientsJSON` — NOT the raw
    /// `recipe.ingredients` of the current parse. `mergeDetail` preserves the
    /// cached JSON via ``applyIngredientsAndInstructions(from:to:)`` when a
    /// partial/truncated recipe-kind re-parse yields `[]`; indexing the raw
    /// empty list instead would still wipe every index row for a recipe whose
    /// cached ingredients are otherwise intact, silently breaking
    /// ingredient-name search. Correctly returns `[]` for an article too,
    /// since its `ingredientsJSON` is unconditionally cleared above.
    func indexIngredients(from target: CachedRecipe) -> [RecipeIngredient] {
        (target.ingredientsJSON.flatMap {
            try? Self.decoder.decode([RecipeIngredient].self, from: $0)
        }) ?? []
    }

    /// DUT-592: copy `ingredients`/`instructions` onto the cached row WITHOUT
    /// clobbering previously-good content with `[]`. For a `.recipe`, a
    /// partial/truncated re-parse (a WPRM markup change, a throttled fetch, an
    /// unhandled JSON-LD variant) can yield an empty array; overwriting would wipe
    /// content a saved/downloaded recipe needs offline (AC-4.9 / AC-5.2), so we
    /// only overwrite when the parse actually produced content — matching the
    /// DUT-399 don't-clobber-with-empty convention. An `.article` legitimately has
    /// none, so it clears them unconditionally (unchanged behavior).
    func applyIngredientsAndInstructions(from recipe: Recipe, to target: CachedRecipe) throws {
        switch recipe.kind {
        case .recipe:
            if !recipe.ingredients.isEmpty {
                target.ingredientsJSON = try Self.encoder.encode(recipe.ingredients)
            }
            if !recipe.instructions.isEmpty {
                target.instructionsJSON = try Self.encoder.encode(recipe.instructions)
            }
        case .article:
            target.ingredientsJSON = try Self.encoder.encode(recipe.ingredients)
            target.instructionsJSON = try Self.encoder.encode(recipe.instructions)
        }
    }

    /// DUT-399: copy the parsed detail fields onto the cached row WITHOUT
    /// clobbering previously-good values with nil. A partial re-parse (e.g.
    /// `backfillIngredientsIfEmpty` recovering ingredients but not nutrition/time
    /// this pass) must not silently wipe the cached nutrition panel + cook-time —
    /// matching the `categoryIDs` / `heroImageLargeURLString` guards in `mergeDetail`.
    /// Extracted from `RecipeStore.swift` to keep that file under the file_length cap.
    func applyParsedDetailFields(from recipe: Recipe, to target: CachedRecipe) {
        func encoded<T: Encodable>(_ value: T?) -> Data? {
            value.flatMap { try? Self.encoder.encode($0) }
        }
        target.nutritionJSON = encoded(recipe.nutrition) ?? target.nutritionJSON
        target.videoJSON = encoded(recipe.video) ?? target.videoJSON
        target.prepSeconds = recipe.prepTime.map(Self.secondsOf) ?? target.prepSeconds
        target.cookSeconds = recipe.cookTime.map(Self.secondsOf) ?? target.cookSeconds
        target.totalSeconds = recipe.totalTime.map(Self.secondsOf) ?? target.totalSeconds
        target.servings = recipe.servings ?? target.servings
        // DUT-572 / CL-310: editorial info fields. Same don't-clobber-with-empty
        // convention — a re-parse that misses these (e.g. a WPRM card that omits
        // recipeCategory) must not wipe a previously-good cached value.
        target.recipeCategory = recipe.recipeCategory.isEmpty ? target.recipeCategory : recipe.recipeCategory
        target.recipeCuisine = recipe.recipeCuisine.isEmpty ? target.recipeCuisine : recipe.recipeCuisine
        target.suitableForDiet = recipe.suitableForDiet.isEmpty ? target.suitableForDiet : recipe.suitableForDiet
        target.author = recipe.author ?? target.author
    }
}
