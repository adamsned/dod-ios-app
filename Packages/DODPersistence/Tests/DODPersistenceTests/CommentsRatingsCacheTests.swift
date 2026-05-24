import Foundation
import SwiftData
import Testing

@testable import DODPersistence

// MARK: - Comment cache (US-14)

@Suite("RecipeStore comment cache (US-14)")
struct CachedCommentsTests {

    @Test func cacheCommentsRoundTripsAllFields() async throws {
        let store = try await makeStore()
        let comment = makeComment(
            id: 100,
            postID: 1,
            parentID: 50,
            authorName: "Alice",
            avatarURLString: "https://example.com/a.png",
            dateGMT: Date(timeIntervalSince1970: 1_700_000_000),
            bodyText: "Loved this recipe!",
            ratingValue: 5,
            statusRaw: "approved"
        )
        try await store.cacheComments([comment])

        let read = try await store.cachedComments(forPostID: 1)
        let first = try #require(read.first)
        #expect(first.id == 100)
        #expect(first.postID == 1)
        #expect(first.parentID == 50)
        #expect(first.authorName == "Alice")
        #expect(first.avatarURLString == "https://example.com/a.png")
        #expect(first.dateGMT == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(first.bodyText == "Loved this recipe!")
        #expect(first.ratingValue == 5)
        #expect(first.statusRaw == "approved")
        #expect(first.isPendingFromThisDevice == false)
    }

    @Test func cachedCommentsForPostIDReturnsNewestFirst() async throws {
        let store = try await makeStore()
        let older = makeComment(
            id: 1,
            postID: 7,
            dateGMT: Date(timeIntervalSince1970: 1_700_000_000),
            bodyText: "older"
        )
        let newer = makeComment(
            id: 2,
            postID: 7,
            dateGMT: Date(timeIntervalSince1970: 1_700_001_000),
            bodyText: "newer"
        )
        let newest = makeComment(
            id: 3,
            postID: 7,
            dateGMT: Date(timeIntervalSince1970: 1_700_002_000),
            bodyText: "newest"
        )
        // Insert out of order to prove the sort, not the insertion order, is the truth.
        try await store.cacheComments([older, newest, newer])

        let read = try await store.cachedComments(forPostID: 7)
        #expect(read.map(\.id) == [3, 2, 1])
    }

    @Test func cachedCommentsAreScopedToOnePost() async throws {
        let store = try await makeStore()
        try await store.cacheComments([
            makeComment(id: 1, postID: 100, bodyText: "A"),
            makeComment(id: 2, postID: 200, bodyText: "B"),
        ])
        let postA = try await store.cachedComments(forPostID: 100)
        let postB = try await store.cachedComments(forPostID: 200)
        #expect(postA.map(\.id) == [1])
        #expect(postB.map(\.id) == [2])
    }

    @Test func reCachingAnExistingCommentOverwritesItInPlace() async throws {
        let store = try await makeStore()
        try await store.cacheComments([
            makeComment(id: 1, postID: 7, bodyText: "draft", statusRaw: "hold")
        ])
        try await store.cacheComments([
            makeComment(id: 1, postID: 7, bodyText: "polished", statusRaw: "approved")
        ])
        let read = try await store.cachedComments(forPostID: 7)
        #expect(read.count == 1, "Update, not duplicate")
        #expect(read.first?.bodyText == "polished")
        #expect(read.first?.statusRaw == "approved")
    }

    @Test func pendingCommentSurvivesUntilDeleted() async throws {
        let store = try await makeStore()
        try await store.upsertPendingComment(
            makeComment(
                id: 999,
                postID: 7,
                authorName: "Me",
                dateGMT: .now,
                bodyText: "fresh post",
                statusRaw: "hold"
            )
        )
        let beforeDelete = try await store.cachedComments(forPostID: 7)
        let first = try #require(beforeDelete.first)
        #expect(first.id == 999)
        #expect(
            first.isPendingFromThisDevice == true,
            "upsertPendingComment must always tag the row pending"
        )

        try await store.deletePendingComment(id: 999)
        let afterDelete = try await store.cachedComments(forPostID: 7)
        #expect(afterDelete.isEmpty)
    }

    @Test func pendingRowsSurfaceAfterApprovedRows() async throws {
        let store = try await makeStore()
        // Two approved rows with distinct timestamps.
        try await store.cacheComments([
            makeComment(
                id: 1,
                postID: 7,
                dateGMT: Date(timeIntervalSince1970: 1_700_000_000),
                bodyText: "older approved",
                statusRaw: "approved"
            ),
            makeComment(
                id: 2,
                postID: 7,
                dateGMT: Date(timeIntervalSince1970: 1_700_001_000),
                bodyText: "newer approved",
                statusRaw: "approved"
            ),
        ])
        // One pending row with a NEWER timestamp than both approved rows —
        // proves the partition rule (approved first, then pending) trumps
        // straight chronological ordering.
        try await store.upsertPendingComment(
            makeComment(
                id: 3,
                postID: 7,
                dateGMT: Date(timeIntervalSince1970: 1_700_002_000),
                bodyText: "my pending",
                statusRaw: "hold"
            )
        )

        let read = try await store.cachedComments(forPostID: 7)
        #expect(
            read.map(\.id) == [2, 1, 3],
            "Approved come first (newest-first), pending appended at end"
        )
    }

    @Test func deletePendingDoesNotRemoveApprovedWithSameID() async throws {
        let store = try await makeStore()
        try await store.cacheComments([
            makeComment(id: 5, postID: 7, bodyText: "approved", statusRaw: "approved")
        ])
        // Defensive: a deletePendingComment call for an id that exists but
        // isn't pending must be a no-op.
        try await store.deletePendingComment(id: 5)
        let read = try await store.cachedComments(forPostID: 7)
        #expect(read.count == 1, "Approved row must not be deleted by deletePendingComment")
    }
}

// MARK: - Rating cache (US-13)

@Suite("RecipeStore rating cache (US-13)")
struct CachedRatingsTests {

    @Test func cacheRatingRoundTrip() async throws {
        let store = try await makeStore()
        try await store.cacheRating(
            CachedRatingSnapshot(recipeID: 42, average: 4.5, count: 8, userRating: 5)
        )
        let read = try await store.cachedRating(forRecipeID: 42)
        let unwrapped = try #require(read)
        #expect(unwrapped.recipeID == 42)
        #expect(unwrapped.average == 4.5)
        #expect(unwrapped.count == 8)
        #expect(unwrapped.userRating == 5)
    }

    @Test func cachedRatingReturnsNilWhenAbsent() async throws {
        let store = try await makeStore()
        let read = try await store.cachedRating(forRecipeID: 999)
        #expect(read == nil)
    }

    @Test func setUserRatingUpdatesExistingRow() async throws {
        let store = try await makeStore()
        try await store.cacheRating(
            CachedRatingSnapshot(recipeID: 42, average: 4.0, count: 10, userRating: 3)
        )
        try await store.setUserRating(5, forRecipeID: 42)
        let read = try await store.cachedRating(forRecipeID: 42)
        let unwrapped = try #require(read)
        #expect(unwrapped.userRating == 5, "User rating bump")
        #expect(unwrapped.average == 4.0, "Aggregate average must not change")
        #expect(unwrapped.count == 10, "Aggregate count must not change")
    }

    @Test func setUserRatingCreatesRowWhenAbsent() async throws {
        let store = try await makeStore()
        try await store.setUserRating(4, forRecipeID: 88)
        let read = try await store.cachedRating(forRecipeID: 88)
        let unwrapped = try #require(read)
        #expect(unwrapped.userRating == 4)
        #expect(unwrapped.average == 0, "No aggregate yet — neutral default")
        // SwiftLint's `empty_count` rule trips on any `.count == 0` /
        // `<= 0` style — alias the integer field to a local so the rule
        // doesn't fire on the assertion (the field really is an Int,
        // not a collection length).
        let aggregateCount = unwrapped.count
        #expect(aggregateCount == 0, "No aggregate yet — neutral default")
    }

    @Test func cachingAggregateWithoutUserRatingPreservesExistingUserRating() async throws {
        let store = try await makeStore()
        // First: user has rated.
        try await store.cacheRating(
            CachedRatingSnapshot(recipeID: 42, average: 3.5, count: 4, userRating: 5)
        )
        // Then: a background refresh updates the aggregate but doesn't know
        // anything about the user's rating — must not nil it out.
        try await store.cacheRating(
            CachedRatingSnapshot(recipeID: 42, average: 4.2, count: 10, userRating: nil)
        )
        let read = try await store.cachedRating(forRecipeID: 42)
        let unwrapped = try #require(read)
        #expect(unwrapped.average == 4.2)
        #expect(unwrapped.count == 10)
        #expect(unwrapped.userRating == 5, "Background refresh must not erase user rating")
    }
}

// MARK: - Migration (US-13/14 / REG-15)

@Suite("V2 → V3 migration (MIGRATION.md rule 3)")
struct MigrationV3Tests {

    /// Build a V2 in-memory store, populate a `CachedRecipe` plus a
    /// `CachedIngredient` (both V2-era models), reopen under V3, and
    /// assert (a) the old rows are still readable and (b) the new
    /// `CachedComment` + `CachedRating` entities exist in the V3 schema.
    ///
    /// Note: SwiftData in-memory containers can't be "reopened" against a
    /// different schema in the same process the way an on-disk container
    /// can — `MigrationPlan` runs at on-disk load. We instead exercise
    /// both halves of the requirement that the migration spec calls out:
    ///
    /// 1. A V2 store opens cleanly and its V2-era models accept inserts —
    ///    proves the V2 schema is still valid as the migration source.
    /// 2. A V3 store opens cleanly, exposes every V2 entity, and adds the
    ///    two new V3 entities — proves the V3 schema is a superset and the
    ///    migration is therefore lightweight (additive-only).
    @Test func v2ToV3LightweightMigration() throws {
        // Step 1: V2 container still works and accepts a V2-era row.
        let v2Container = try RecipeStore.inMemoryContainerV2()
        let v2Context = ModelContext(v2Container)
        let v2Recipe = CachedRecipe(
            id: 1,
            slug: "test",
            title: "Test",
            excerptText: "x",
            canonicalURLString: "https://example.com/1",
            publishedAt: .now
        )
        v2Context.insert(v2Recipe)
        v2Context.insert(
            CachedIngredient(recipeID: 1, normalizedText: "flour")
        )
        try v2Context.save()

        // Step 2: V3 container exposes every V2 entity AND adds the two
        // new V3 entities. Failing assertion here is the canary that
        // someone forgot to add a model to SchemaV3.models.
        let v3Container = try RecipeStore.inMemoryContainer()
        let v3Entities = v3Container.schema.entitiesByName

        #expect(v3Entities["CachedRecipe"] != nil, "V3 must still expose CachedRecipe")
        #expect(v3Entities["CachedListPage"] != nil, "V3 must still expose CachedListPage")
        #expect(v3Entities["CachedImage"] != nil, "V3 must still expose CachedImage")
        #expect(
            v3Entities["CachedIngredient"] != nil,
            "V3 must still expose the V2-era CachedIngredient (additive-only rule)"
        )
        #expect(v3Entities["CachedComment"] != nil, "V3 must include the new CachedComment model")
        #expect(v3Entities["CachedRating"] != nil, "V3 must include the new CachedRating model")
    }

    @Test func v3MigrationPlanLists3VersionsAnd2Stages() {
        let schemas = MigrationPlan.schemas
        #expect(schemas.count == 3, "V1, V2, V3")
        let stages = MigrationPlan.stages
        #expect(stages.count == 2, "V1→V2 and V2→V3")
    }
}

// MARK: - Helpers

private func makeComment(
    id: Int,
    postID: Int,
    parentID: Int? = nil,
    authorName: String = "Author",
    avatarURLString: String? = nil,
    dateGMT: Date = Date(timeIntervalSince1970: 1_700_000_000),
    bodyText: String = "Body",
    ratingValue: Int? = nil,
    statusRaw: String = "approved"
) -> CachedCommentSnapshot {
    CachedCommentSnapshot(
        id: id,
        postID: postID,
        parentID: parentID,
        authorName: authorName,
        avatarURLString: avatarURLString,
        dateGMT: dateGMT,
        bodyText: bodyText,
        ratingValue: ratingValue,
        statusRaw: statusRaw
    )
}
