import DODDomain
import Foundation
import Testing

@testable import DODPersistence

/// DUT-591 (Medium) — `evictIfNeeded()` deleted only the `CachedRecipe` row when
/// a recipe fell out of the 100-row unsaved LRU window, orphaning its
/// `CachedIngredient`/`CachedComment`/`CachedRating` rows (they link by a plain
/// `Int` with no `@Relationship`/cascade rule). Those tables then grew without
/// bound and never self-healed. The fix sweeps the dependent rows for each
/// evicted id in the same transaction. These prove the cascade fires on eviction
/// and does NOT touch rows for recipes that stay in the window.
@Suite("LRU eviction cascades to dependent rows (DUT-591)")
struct EvictionCascadeTests {

    private func seedDependents(_ store: RecipeStore, recipeID: Int) async throws {
        // Ingredient-index rows via a real mergeDetail (writes CachedIngredient).
        try await store.mergeDetail(
            makeRecipe(id: recipeID, ingredients: ["2 cups flour", "1 tsp salt"])
        )
        // A cached comment on the post.
        try await store.cacheComments([
            CachedCommentSnapshot(
                id: recipeID * 1000,
                postID: recipeID,
                authorName: "Cook",
                dateGMT: Date(timeIntervalSince1970: 1_700_000_000),
                bodyText: "Delicious!",
                statusRaw: "approved"
            )
        ])
        // An aggregate-only rating (userRating == nil) — a re-fetchable cache of
        // WP's public average, so the cascade is allowed to sweep it. Device-
        // authored ratings (userRating != nil) survive and are covered
        // separately by `evictionPreservesUserRatingAndPendingComment`.
        try await store.cacheRating(
            CachedRatingSnapshot(recipeID: recipeID, average: 4.5, count: 12, userRating: nil)
        )
    }

    /// Overflowing the LRU evicts the oldest unsaved recipe AND deletes its
    /// dependent ingredient/comment/rating rows — no orphans left behind.
    @Test func evictionDeletesDependentRows() async throws {
        let store = try await makeStore()

        // The victim: the oldest-viewed recipe, seeded with all three dependents.
        let victimID = 1
        try await store.cache(listItem: makeListItem(id: victimID, title: "Victim"))
        try await seedDependents(store, recipeID: victimID)

        // Sanity: the dependents exist before eviction.
        #expect(try await store.ingredientIndexCount(forRecipeID: victimID) == 2)
        #expect(try await store.cachedComments(forPostID: victimID).count == 1)
        #expect(try await store.cachedRating(forRecipeID: victimID) != nil)

        // Push the victim out of the window: fill past the cap with newer rows.
        // `makeListItem` stamps `publishedAt` by id, but LRU sorts on
        // `lastViewedAt` (set to .now on each cache), so inserting the victim
        // FIRST makes it the oldest and therefore the eviction target.
        for index in 0..<(RecipeStore.unsavedLRUCap + 5) {
            try await store.cache(listItem: makeListItem(id: 100 + index, title: "Filler \(index)"))
        }

        // The victim's CachedRecipe is gone...
        let victimRow = try await store.listItems(forIDs: [victimID])
        #expect(victimRow.isEmpty)
        // ...and so are ALL of its dependent rows (DUT-591 — previously orphaned).
        #expect(try await store.ingredientIndexCount(forRecipeID: victimID) == 0)
        #expect(try await store.cachedComments(forPostID: victimID).isEmpty)
        #expect(try await store.cachedRating(forRecipeID: victimID) == nil)
    }

    /// DUT-417 / DUT-439 — the cascade must NOT destroy device-authoritative,
    /// non-re-fetchable state when a recipe is evicted: the user's own star
    /// rating (`CachedRating.userRating != nil`, backing `userRatingCount()`)
    /// and the user's own pending-from-this-device comment survive, while the
    /// re-fetchable aggregate-only rating + approved (public) comment rows for
    /// the same evicted recipes ARE swept.
    @Test func evictionPreservesUserRatingAndPendingComment() async throws {
        let store = try await makeStore()

        // Victim A: the user rated it (userRating = 5) and posted a comment that
        // WP hasn't approved yet (pending), plus one already-approved comment.
        let ratedID = 1
        try await store.cache(listItem: makeListItem(id: ratedID, title: "Rated"))
        try await store.cacheRating(
            CachedRatingSnapshot(recipeID: ratedID, average: 4.5, count: 12, userRating: 5)
        )
        try await store.cacheComments([
            CachedCommentSnapshot(
                id: 1002,
                postID: ratedID,
                authorName: "Cook",
                dateGMT: Date(timeIntervalSince1970: 1_700_000_000),
                bodyText: "Approved public comment",
                statusRaw: "approved"
            )
        ])
        try await store.upsertPendingComment(
            CachedCommentSnapshot(
                id: 1001,
                postID: ratedID,
                authorName: "Me",
                dateGMT: .now,
                bodyText: "My pending comment",
                statusRaw: "hold"
            )
        )

        // Victim B: only an aggregate-only rating (userRating = nil) — a plain
        // cache of WP's public average, fully re-fetchable, so it may be swept.
        let aggregateID = 2
        try await store.cache(listItem: makeListItem(id: aggregateID, title: "Aggregate"))
        try await store.cacheRating(
            CachedRatingSnapshot(recipeID: aggregateID, average: 3.0, count: 4, userRating: nil)
        )

        // Sanity before eviction: exactly one user-rated row.
        #expect(try await store.userRatingCount() == 1)

        // Push both victims out of the window (they were inserted first, so they
        // are the oldest by `lastViewedAt` and evict first).
        for index in 0..<(RecipeStore.unsavedLRUCap + 5) {
            try await store.cache(listItem: makeListItem(id: 100 + index, title: "Filler \(index)"))
        }

        // Both victim recipes are gone from the cache...
        #expect(try await store.listItems(forIDs: [ratedID, aggregateID]).isEmpty)

        // ...but the user's own rating survives (userRatingCount unchanged) even
        // though its CachedRecipe was evicted.
        #expect(try await store.userRatingCount() == 1)
        #expect(try await store.cachedRating(forRecipeID: ratedID)?.userRating == 5)
        // The aggregate-only rating for the other evicted recipe IS swept.
        #expect(try await store.cachedRating(forRecipeID: aggregateID) == nil)

        // The pending-from-this-device comment survives; the approved public
        // comment for the same recipe is swept.
        let comments = try await store.cachedComments(forPostID: ratedID)
        #expect(comments.map(\.id) == [1001], "Only the pending comment survives eviction")
        #expect(comments.first?.isPendingFromThisDevice == true)
    }

    /// A recipe that stays inside the LRU window keeps all of its dependent rows —
    /// the cascade only touches evicted ids.
    @Test func survivingRecipeKeepsDependentRows() async throws {
        let store = try await makeStore()

        // Insert the survivor LAST so it's the most-recently-viewed and never
        // evicted, then seed its dependents.
        for index in 0..<(RecipeStore.unsavedLRUCap + 5) {
            try await store.cache(listItem: makeListItem(id: 100 + index, title: "Filler \(index)"))
        }
        let survivorID = 7
        try await store.cache(listItem: makeListItem(id: survivorID, title: "Survivor"))
        try await seedDependents(store, recipeID: survivorID)
        // mergeDetail/cache above already ran an evict pass; run one more to be sure.
        try await store.evictIfNeeded()

        // The survivor and every dependent row is intact.
        #expect(try await store.listItems(forIDs: [survivorID]).count == 1)
        #expect(try await store.ingredientIndexCount(forRecipeID: survivorID) == 2)
        #expect(try await store.cachedComments(forPostID: survivorID).count == 1)
        #expect(try await store.cachedRating(forRecipeID: survivorID) != nil)
    }
}
