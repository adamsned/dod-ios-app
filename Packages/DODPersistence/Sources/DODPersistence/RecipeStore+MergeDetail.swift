import DODDomain
import Foundation

extension RecipeStore {

    /// DUT-399: copy the parsed detail fields onto the cached row WITHOUT
    /// clobbering previously-good values with nil. A partial re-parse (e.g.
    /// `backfillIngredientsIfEmpty` recovering ingredients but not nutrition/time
    /// this pass) must not silently wipe the cached nutrition panel + cook-time —
    /// matching the `categoryIDs` / `heroImageLargeURLString` guards in `mergeDetail`.
    /// Extracted from `RecipeStore.swift` to keep that file under the file_length cap.
    func applyParsedDetailFields(from recipe: Recipe, to target: CachedRecipe) {
        func encoded<T: Encodable>(_ value: T?) -> Data? {
            value.flatMap { try? JSONEncoder().encode($0) }
        }
        target.nutritionJSON = encoded(recipe.nutrition) ?? target.nutritionJSON
        target.videoJSON = encoded(recipe.video) ?? target.videoJSON
        target.prepSeconds = recipe.prepTime.map(Self.secondsOf) ?? target.prepSeconds
        target.cookSeconds = recipe.cookTime.map(Self.secondsOf) ?? target.cookSeconds
        target.totalSeconds = recipe.totalTime.map(Self.secondsOf) ?? target.totalSeconds
        target.servings = recipe.servings ?? target.servings
    }
}
