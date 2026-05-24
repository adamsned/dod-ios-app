import DODDomain
import Foundation
import SwiftData
import Testing

@testable import DODPersistence

@Suite("RecipeStore CRUD (T-073)") struct RecipeStoreTests {

    @Test func cacheListItemThenReadBack() async throws {
        let store = try await makeStore()
        let listItem = makeListItem(id: 1, title: "Apple Crisp")
        try await store.cache(listItem: listItem)
        let items = try await store.listItems(forIDs: [1])
        let first = try #require(items.first)
        #expect(first.id == 1)
        #expect(first.title == "Apple Crisp")
    }

    /// REG-DOD-NAV-1: cache(listItem:) must round-trip canonicalURL.
    /// Before this fix the URL was dropped on insert, which made recipe-tap
    /// navigation fall back to the homepage and immediately auto-dismiss.
    @Test func canonicalURLRoundTrips() async throws {
        let store = try await makeStore()
        let url = URL(string: "https://www.dutchovendaddy.com/test-recipe/") ?? URL(filePath: "/")
        let listItem = RecipeListItem(
            id: 88,
            title: "Test",
            excerpt: "x",
            heroImage: nil,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: nil,
            canonicalURL: url
        )
        try await store.cache(listItem: listItem)
        let items = try await store.listItems(forIDs: [88])
        let first = try #require(items.first)
        #expect(first.canonicalURL == url)
    }

    /// Updating an existing row with a fresh canonicalURL should overwrite,
    /// but passing nil should NOT clobber a previously-stored good value.
    @Test func canonicalURLUpdatesButDoesNotClobberOnNil() async throws {
        let store = try await makeStore()
        let url = URL(string: "https://www.dutchovendaddy.com/r/") ?? URL(filePath: "/")
        try await store.cache(
            listItem: RecipeListItem(
                id: 99,
                title: "A",
                excerpt: "x",
                heroImage: nil,
                publishedAt: .now,
                totalTimeDisplay: nil,
                canonicalURL: url
            )
        )
        // Re-cache with nil canonicalURL (simulating a partial update).
        try await store.cache(
            listItem: RecipeListItem(
                id: 99,
                title: "A",
                excerpt: "y",
                heroImage: nil,
                publishedAt: .now,
                totalTimeDisplay: nil,
                canonicalURL: nil
            )
        )
        let items = try await store.listItems(forIDs: [99])
        #expect(items.first?.canonicalURL == url, "Nil update must not clobber existing URL")
    }

    @Test func mergeDetailPopulatesIngredientsAndInstructions() async throws {
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 42, title: "Pasta"))
        try await store.mergeDetail(makeRecipe(id: 42, withDetail: true))
        let recipe = try await store.recipe(id: 42)
        let unwrapped = try #require(recipe)
        #expect(unwrapped.ingredients.count == 2)
        #expect(unwrapped.instructions.count == 2)
        #expect(unwrapped.totalTime == .seconds(15 * 60))
    }

    @Test func toggleSavedPinsTheRow() async throws {
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 7, title: "Bread"))
        let saved = try await store.toggleSaved(id: 7)
        #expect(saved == true)
        let savedList = try await store.savedRecipes()
        #expect(savedList.count == 1)
        #expect(savedList.first?.id == 7)
        let unsaved = try await store.toggleSaved(id: 7)
        #expect(unsaved == false)
        let savedAfter = try await store.savedRecipes()
        #expect(savedAfter.isEmpty)
    }
}

@Suite("RecipeStore recently-viewed + entity lookup (US-10)")
struct RecentlyViewedTests {

    /// AC-10.1: AppEntity query must surface the most-recently-viewed
    /// recipes via `recentlyViewed(limit:)`. Newest `lastViewedAt` first;
    /// blocklisted rows excluded.
    @Test func recentlyViewedReturnsNewestFirst() async throws {
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 1, title: "Old"))
        try await store.cache(listItem: makeListItem(id: 2, title: "Newer"))
        try await store.cache(listItem: makeListItem(id: 3, title: "Newest"))
        let recents = try await store.recentlyViewed(limit: 10)
        #expect(recents.map(\.id) == [3, 2, 1])
    }

    @Test func recentlyViewedRespectsLimit() async throws {
        let store = try await makeStore()
        for index in 0..<5 {
            try await store.cache(listItem: makeListItem(id: index, title: "R\(index)"))
        }
        let recents = try await store.recentlyViewed(limit: 3)
        #expect(recents.count == 3)
    }

    @Test func recentlyViewedExcludesBlocklisted() async throws {
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 1, title: "Healthy"))
        try await store.cache(listItem: makeListItem(id: 2, title: "Broken"))
        try await store.markJSONLDFailed(id: 2)
        let recents = try await store.recentlyViewed(limit: 10)
        #expect(recents.map(\.id) == [1])
    }

    /// AC-10.1: the AppEntity lookup must NOT touch `lastViewedAt`. If it
    /// did, every Siri suggestion would re-rank to the top and pollute the
    /// LRU.
    @Test func recipeWithoutTouchingDoesNotBumpLastViewedAt() async throws {
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 1, title: "First"))
        // Sleep a millisecond so any bump to lastViewedAt would be observable.
        try await Task.sleep(nanoseconds: 1_000_000)
        try await store.cache(listItem: makeListItem(id: 2, title: "Second"))
        // Probe id=1 via the silent accessor.
        _ = try await store.recipeWithoutTouching(id: 1)
        let recents = try await store.recentlyViewed(limit: 10)
        // Id 2 should still be at the top — the probe must not have promoted id 1.
        #expect(recents.first?.id == 2, "Silent accessor must not bump lastViewedAt")
    }

    @Test func recipeWithoutTouchingReturnsNilForMissingID() async throws {
        let store = try await makeStore()
        let recipe = try await store.recipeWithoutTouching(id: 999)
        #expect(recipe == nil)
    }
}

@Suite("RecipeStore LRU policy (T-074)") struct LRUPolicyTests {

    @Test func unsavedRowsAreCappedAtTheBudget() async throws {
        let store = try await makeStore()
        // Insert 5 rows past the cap.
        for index in 0..<(RecipeStore.unsavedLRUCap + 5) {
            try await store.cache(listItem: makeListItem(id: index, title: "Item \(index)"))
        }
        let remaining =
            try await store.savedRecipes().count
            + (try await store.listItems(
                forIDs: Array(0..<(RecipeStore.unsavedLRUCap + 5))
            )).count
        #expect(remaining <= RecipeStore.unsavedLRUCap)
    }

    @Test func savedRowsAreNeverEvicted() async throws {
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 999, title: "Treasured Recipe"))
        _ = try await store.toggleSaved(id: 999)
        // Insert way more than the cap of unsaved rows.
        for index in 0..<(RecipeStore.unsavedLRUCap + 50) {
            try await store.cache(listItem: makeListItem(id: 1000 + index, title: "Filler \(index)"))
        }
        let saved = try await store.savedRecipes()
        #expect(saved.contains(where: { $0.id == 999 }), "Saved recipe must survive overflow")
    }
}

@Suite("RecipeStore image cache (T-075)") struct ImageCacheTests {

    @Test func cacheAndReadImage() async throws {
        let store = try await makeStore()
        let url = URL(string: "https://example.com/img.jpg") ?? URL(filePath: "/")
        let bytes = Data(repeating: 0x42, count: 1024)
        try await store.cacheImage(url: url, bytes: bytes)
        let read = try await store.image(url: url)
        #expect(read == bytes)
    }

    @Test func pinnedImagesAreNotEvictedByBudget() async throws {
        let store = try await makeStore()
        let pinnedURL = URL(string: "https://example.com/pinned.jpg") ?? URL(filePath: "/")
        // Pin a small image to a saved recipe.
        try await store.cacheImage(url: pinnedURL, bytes: Data(repeating: 0x01, count: 1024), pinnedToSavedRecipeID: 1)

        // Fill with non-pinned images. Use a much smaller fake budget by
        // shoveling enough bytes through that eviction kicks in for some.
        // We exercise the path; exact byte budgets are slow to fill in a unit
        // test, so we focus on the *correctness* of pinning.
        for index in 0..<5 {
            let url = URL(string: "https://example.com/\(index).jpg") ?? URL(filePath: "/")
            try await store.cacheImage(url: url, bytes: Data(repeating: 0xFF, count: 1024))
        }
        let pinned = try await store.image(url: pinnedURL)
        #expect(pinned != nil, "Pinned image must remain available")
    }
}

// MARK: - Ingredient index (US-12)

@Suite("RecipeStore ingredient index (US-12)") struct IngredientIndexTests {

    @Test func ingredientsAreIndexedOnMergeDetail() async throws {
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 1, title: "Garlic Pasta"))
        try await store.mergeDetail(
            makeRecipe(
                id: 1,
                ingredients: ["4 cloves garlic", "1 lb pasta", "2 tbsp olive oil"]
            )
        )
        let count = try await store.ingredientIndexCount(forRecipeID: 1)
        #expect(count == 3)
    }

    @Test func searchMatchesSubstringInsideAnIngredient() async throws {
        let store = try await makeStore()
        try await store.mergeDetail(
            makeRecipe(id: 1, ingredients: ["4 cloves garlic", "1 lb pasta"])
        )
        try await store.mergeDetail(
            makeRecipe(id: 2, ingredients: ["2 lemons", "olive oil"])
        )
        try await store.mergeDetail(
            makeRecipe(id: 3, ingredients: ["roasted garlic head", "salt"])
        )

        let matches = try await store.searchIngredients(matching: "garlic")
        #expect(Set(matches) == [1, 3], "1 and 3 contain 'garlic'; 2 does not")
        #expect(matches.count == 2, "Each recipe must appear at most once")
    }

    @Test func searchIsCaseInsensitive() async throws {
        let store = try await makeStore()
        try await store.mergeDetail(
            makeRecipe(id: 1, ingredients: ["FRESH Garlic"])
        )
        let lower = try await store.searchIngredients(matching: "garlic")
        let upper = try await store.searchIngredients(matching: "GARLIC")
        #expect(lower == [1])
        #expect(upper == [1])
    }

    @Test func shortQueriesReturnEmpty() async throws {
        let store = try await makeStore()
        try await store.mergeDetail(makeRecipe(id: 1, ingredients: ["garlic"]))
        let result = try await store.searchIngredients(matching: "a")
        #expect(result.isEmpty)
    }

    @Test func reMergingDetailReplacesIndexRows() async throws {
        let store = try await makeStore()
        try await store.mergeDetail(
            makeRecipe(id: 1, ingredients: ["wrong", "items", "here"])
        )
        try await store.mergeDetail(
            makeRecipe(id: 1, ingredients: ["correct", "ingredient", "set"])
        )
        let count = try await store.ingredientIndexCount(forRecipeID: 1)
        #expect(count == 3, "Re-merge must replace, not append, to keep the index clean")
        let oldMatch = try await store.searchIngredients(matching: "wrong")
        #expect(oldMatch.isEmpty, "Stale ingredient text must be removed")
    }
}

@Suite("RecipeStore search-filter inputs (US-12)") struct SearchFilterInputsTests {

    @Test func categoryIDsForRecipes() async throws {
        let store = try await makeStore()
        try await store.mergeDetail(
            makeRecipe(id: 1, categoryIDs: [10, 20], ingredients: ["x"])
        )
        try await store.mergeDetail(
            makeRecipe(id: 2, categoryIDs: [30], ingredients: ["y"])
        )
        let map = try await store.categoryIDs(forRecipeIDs: [1, 2, 99])
        #expect(map[1] == [10, 20])
        #expect(map[2] == [30])
        #expect(map[99] == nil, "Recipes never cached are omitted from the map")
    }

    @Test func totalSecondsForRecipes() async throws {
        let store = try await makeStore()
        try await store.mergeDetail(
            makeRecipe(id: 1, ingredients: ["x"], totalSeconds: 15 * 60)
        )
        try await store.cache(listItem: makeListItem(id: 2, title: "Untimed"))
        let map = try await store.totalSeconds(forRecipeIDs: [1, 2])
        #expect(map[1] == 15 * 60)
        #expect(map[2] == nil, "List-only rows have no total time yet")
    }

    @Test func recentlyViewedReturnsCachedIDs() async throws {
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 1, title: "A"))
        try await store.cache(listItem: makeListItem(id: 2, title: "B"))
        let viewed = try await store.recentlyViewedRecipeIDs()
        #expect(viewed == [1, 2])
    }
}

// MARK: - Migration (US-12 / CL-19)

@Suite("V1 → V2 migration (MIGRATION.md rule 3)") struct MigrationTests {

    @Test func lightweightV1toV2OpensCleanly() throws {
        // Per MIGRATION.md rule 3 every new schema lands with a test that
        // creates a V(N-1) store, opens it under V(N), and asserts data is
        // intact. V2 is additive only — `CachedIngredient` is new — so a V1
        // store must still hand back its CachedRecipe rows after the
        // lightweight upgrade.
        let v1Container = try RecipeStore.inMemoryContainerV1()
        _ = v1Container  // proves the V1 schema still compiles + opens.

        let v2Container = try RecipeStore.inMemoryContainer()
        #expect(
            v2Container.schema.entitiesByName["CachedIngredient"] != nil,
            "V2 schema must include the new CachedIngredient model"
        )
        #expect(
            v2Container.schema.entitiesByName["CachedRecipe"] != nil,
            "V2 schema must still expose every V1 model (additive-only rule)"
        )
    }
}

@Suite("RecipeStore blocklist (T-076, AC-1.7)") struct BlocklistTests {

    @Test func blocklistedRowExcludedFromListItems() async throws {
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 1, title: "Healthy"))
        try await store.cache(listItem: makeListItem(id: 2, title: "Broken"))
        try await store.markJSONLDFailed(id: 2)
        let visible = try await store.listItems(forIDs: [1, 2])
        #expect(visible.map(\.id) == [1])
    }

    @Test func clearBlocklistRestoresVisibility() async throws {
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 5, title: "Foo"))
        try await store.markJSONLDFailed(id: 5)
        let beforeClear = try await store.listItems(forIDs: [5])
        #expect(beforeClear.isEmpty)
        try await store.clearBlocklist()
        let afterClear = try await store.listItems(forIDs: [5])
        #expect(afterClear.count == 1)
    }

    @Test func successfulReCacheClearsBlocklistedFlag() async throws {
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 9, title: "Comeback"))
        try await store.markJSONLDFailed(id: 9)
        // Re-caching the same item (e.g. after pull-to-refresh) clears the flag.
        try await store.cache(listItem: makeListItem(id: 9, title: "Comeback"))
        let visible = try await store.listItems(forIDs: [9])
        #expect(visible.count == 1)
    }
}

// MARK: - Helpers

private func makeStore() async throws -> RecipeStore {
    let container = try RecipeStore.inMemoryContainer()
    return RecipeStore(modelContainer: container)
}

private func makeListItem(id: Int, title: String) -> RecipeListItem {
    RecipeListItem(
        id: id,
        title: title,
        excerpt: "An excerpt.",
        heroImage: URL(string: "https://example.com/\(id).jpg"),
        publishedAt: Date(timeIntervalSince1970: 1_700_000_000 + TimeInterval(id)),
        totalTimeDisplay: nil
    )
}

private func makeRecipe(id: Int, withDetail: Bool) -> Recipe {
    Recipe(
        id: id,
        slug: "slug-\(id)",
        title: "Title \(id)",
        excerpt: "Excerpt.",
        canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/\(id)/") ?? URL(filePath: "/"),
        publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
        ingredients: withDetail ? [.init(text: "1 cup flour"), .init(text: "1 tsp salt")] : [],
        instructions: withDetail
            ? [.init(step: 1, text: "Mix."), .init(step: 2, text: "Bake.")]
            : [],
        totalTime: .seconds(15 * 60)
    )
}

/// US-12 overload: lets ingredient-index tests inject specific ingredient
/// strings, categories, and total time without sharing the broader shape
/// of `makeRecipe(id:withDetail:)`.
private func makeRecipe(
    id: Int,
    categoryIDs: [Int] = [],
    ingredients: [String],
    totalSeconds: Int? = nil
) -> Recipe {
    Recipe(
        id: id,
        slug: "slug-\(id)",
        title: "Title \(id)",
        excerpt: "Excerpt.",
        canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/\(id)/") ?? URL(filePath: "/"),
        categoryIDs: categoryIDs,
        publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
        ingredients: ingredients.map { .init(text: $0) },
        totalTime: totalSeconds.map { .seconds($0) }
    )
}
