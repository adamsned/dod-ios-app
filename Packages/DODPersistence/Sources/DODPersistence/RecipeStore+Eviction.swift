import DODDomain
import Foundation
import SwiftData

/// LRU eviction of the local `CachedRecipe` cache (T-074) plus the DUT-591
/// cascade that tears down each evicted recipe's dependent
/// `CachedIngredient`/`CachedComment`/`CachedRating` rows. Extracted from
/// `RecipeStore.swift` so that file stays under the SwiftLint file_length /
/// type_body_length caps (constitution §10).
extension RecipeStore {

    /// Trim unsaved AND non-downloaded CachedRecipes to ``unsavedLRUCap`` by
    /// oldest `lastViewedAt`. Saved recipes are never evicted (NFR-1);
    /// explicitly-downloaded recipes (US-35 / AC-35.5) are also pinned — the
    /// predicate requires both flags clear before a row is eligible.
    public func evictIfNeeded() throws {
        evictIfNeededCallCount += 1  // DUT-257 test spy; never read in production.
        let descriptor = FetchDescriptor<CachedRecipe>(
            predicate: #Predicate { $0.isSaved == false && $0.downloadedAt == nil },
            sortBy: [SortDescriptor(\.lastViewedAt, order: .forward)]
        )
        let unsaved = try modelContext.fetch(descriptor)
        let overflow = unsaved.count - Self.unsavedLRUCap
        guard overflow > 0 else { return }
        for row in unsaved.prefix(overflow) {
            // DUT-591: `CachedIngredient`/`CachedComment`/`CachedRating` link to a
            // recipe by a plain `Int` (`recipeID`/`postID`) with NO `@Relationship`
            // + no cascade rule, so deleting the `CachedRecipe` alone orphans them —
            // unbounded table growth that never self-heals (they're only cleared on
            // a re-merge of that same recipe, which an evicted row never gets). Sweep
            // the dependent rows for this id in the SAME transaction, mirroring the
            // cook-log photo-teardown discipline.
            try deleteDependentCacheRows(forRecipeID: row.id)
            modelContext.delete(row)
        }
        try modelContext.save()
    }

    /// DUT-591 — delete every `CachedIngredient`/`CachedComment`/`CachedRating`
    /// row tied to `id` (by `recipeID`/`postID`). Called from ``evictIfNeeded()``
    /// so an LRU-evicted recipe leaves no orphaned dependent rows behind. Deletes
    /// into the current transaction; the caller saves.
    private func deleteDependentCacheRows(forRecipeID id: Int) throws {
        let ingredients = try modelContext.fetch(
            FetchDescriptor<CachedIngredient>(predicate: #Predicate { $0.recipeID == id })
        )
        for ingredient in ingredients {
            modelContext.delete(ingredient)
        }
        // DUT-439: a `CachedComment.isPendingFromThisDevice == true` row is the
        // user's OWN submitted-but-unapproved comment. It never comes back from
        // the public GET until WP approves it, so evicting it here would silently
        // destroy device-authoritative state that is NOT re-fetchable. Sweep only
        // the re-fetchable public rows (`isPendingFromThisDevice == false`); the
        // pending row survives eviction and ages out on its own DUT-439 window.
        let comments = try modelContext.fetch(
            FetchDescriptor<CachedComment>(
                predicate: #Predicate { $0.postID == id && $0.isPendingFromThisDevice == false }
            )
        )
        for comment in comments {
            modelContext.delete(comment)
        }
        // DUT-417: a `CachedRating.userRating != nil` row carries the user's own
        // star rating, which backs the profile "Ratings" count via
        // `userRatingCount()` and is NOT re-fetchable from WP. Sweep only the
        // aggregate-only rows (`userRating == nil`, cached from a recipe's public
        // average); the device-authored rating survives even though its
        // `CachedRecipe` is evicted.
        let ratings = try modelContext.fetch(
            FetchDescriptor<CachedRating>(
                predicate: #Predicate { $0.recipeID == id && $0.userRating == nil }
            )
        )
        for rating in ratings {
            modelContext.delete(rating)
        }
    }
}
