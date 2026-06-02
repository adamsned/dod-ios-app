import DODDomain
import Foundation
import SwiftData
import Testing

@testable import DODPersistence

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

    // MARK: - DUT-11: value-type ingredient search

    @Test func recipesUsingIngredientReturnsListItemsForMatchesOnly() async throws {
        // The headline DUT-11 contract: searching an ingredient term returns
        // the recipes that USE it (in their ingredient list) even though the
        // term is NOT in their title — and excludes recipes that don't use it.
        let store = try await makeStore()
        // Titles are "Title <id>" (the makeRecipe overload's default), so none
        // of these contain "ground beef" — the match is purely ingredient-side.
        try await store.mergeDetail(
            makeRecipe(id: 1, ingredients: ["1 lb ground beef", "1 onion"])
        )
        try await store.mergeDetail(
            makeRecipe(id: 2, ingredients: ["2 chicken breasts", "salt"])
        )
        try await store.mergeDetail(
            makeRecipe(id: 3, ingredients: ["½ lb ground beef", "taco seasoning"])
        )

        let hits = try await store.recipesUsingIngredient(matching: "ground beef")
        #expect(
            Set(hits.map(\.id)) == [1, 3],
            "Only recipes whose ingredient lines contain the term are returned"
        )
        #expect(
            hits.allSatisfy { !$0.title.localizedCaseInsensitiveContains("ground beef") },
            "Matches are ingredient-driven — the term is absent from every title"
        )
        // Returns fully-formed list items (title carried through the projection).
        #expect(hits.contains { $0.title == "Title 1" })
    }

    @Test func recipesUsingIngredientDedupesAcrossManyIngredientLines() async throws {
        // A recipe with the term in two separate ingredient lines (and thus
        // two CachedIngredient rows) must appear exactly once in the result.
        let store = try await makeStore()
        try await store.mergeDetail(
            makeRecipe(id: 1, ingredients: ["1 lb ground beef", "more ground beef", "salt"])
        )
        let hits = try await store.recipesUsingIngredient(matching: "ground beef")
        #expect(hits.map(\.id) == [1], "Multiple matching lines collapse to one recipe row")
    }

    @Test func recipesUsingIngredientIsCaseAndDiacriticInsensitive() async throws {
        // normalize() lowercases + folds diacritics on both sides, so a query
        // with different case/accents still matches the stored line.
        let store = try await makeStore()
        try await store.mergeDetail(
            makeRecipe(id: 1, ingredients: ["1 piece Jalapeño Pepper"])
        )
        let upper = try await store.recipesUsingIngredient(matching: "JALAPENO")
        #expect(upper.map(\.id) == [1], "Case + diacritic folding lets 'JALAPENO' match 'Jalapeño'")
    }

    @Test func recipesUsingIngredientReturnsEmptyForNoMatch() async throws {
        let store = try await makeStore()
        try await store.mergeDetail(makeRecipe(id: 1, ingredients: ["1 cup flour"]))
        let hits = try await store.recipesUsingIngredient(matching: "ground beef")
        #expect(hits.isEmpty)
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

    // MARK: - REG-17 (T-530, CL-53): REST categoryIDs round-trip into the cache.

    @Test func categoryIDsRoundTripFromListItem() async throws {
        // Pins T-530 / CL-53 / REG-17's cache-side contract: a freshly-fetched
        // REST hit (no `mergeDetail(_:)` call, no JSON-LD parse yet) must
        // round-trip its `RecipeListItem.categoryIDs` into the cache so
        // `categoryIDs(forRecipeIDs:)` returns the populated array — which
        // is what the Search-tab category chip filters against. Before
        // T-530, `cache(listItem:)` dropped the field on the floor and
        // every fresh REST hit's category-IDs map was empty.
        let store = try await makeStore()
        let listItem = RecipeListItem(
            id: 7,
            title: "Beef Skillet",
            excerpt: "x",
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            categoryIDs: [10, 20]
        )
        try await store.cache(listItem: listItem)
        let map = try await store.categoryIDs(forRecipeIDs: [7])
        #expect(
            map[7] == [10, 20],
            "REST `Post.categories` must round-trip into `CachedRecipe.categoryIDs` via `cache(listItem:)` — REG-17 lock."
        )
    }

    @Test func categoryIDsCacheDoesNotClobberOnNilOrEmptyWireValue() async throws {
        // The cache-side "don't clobber populated data" guard mirrors the
        // existing `canonicalURL` guard at `RecipeStore.swift:32-34`. A
        // recipe that's been opened (and thus has its `CachedRecipe.categoryIDs`
        // populated by `mergeDetail(_:)`) must not have that data wiped by
        // a subsequent feed-refresh REST hit whose payload happens to
        // surface a nil or empty categories array (server glitch, plugin
        // misconfiguration).
        let store = try await makeStore()
        // First, prime the row with a `mergeDetail` so categoryIDs gets populated.
        try await store.mergeDetail(
            makeRecipe(id: 8, categoryIDs: [30, 40], ingredients: ["x"])
        )
        // Now a list-cache pass with nil categoryIDs (the wire-omitted
        // case) and an explicit empty-array categoryIDs (the
        // server-returned-empty case) must both leave the existing
        // populated value untouched.
        let nilCategoriesItem = RecipeListItem(
            id: 8,
            title: "Beef Skillet",
            excerpt: "x",
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            categoryIDs: nil
        )
        try await store.cache(listItem: nilCategoriesItem)
        var map = try await store.categoryIDs(forRecipeIDs: [8])
        #expect(
            map[8] == [30, 40],
            "nil-on-the-wire must not clobber populated cache categoryIDs"
        )

        let emptyCategoriesItem = RecipeListItem(
            id: 8,
            title: "Beef Skillet",
            excerpt: "x",
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            categoryIDs: []
        )
        try await store.cache(listItem: emptyCategoriesItem)
        map = try await store.categoryIDs(forRecipeIDs: [8])
        #expect(
            map[8] == [30, 40],
            "empty-on-the-wire must not clobber populated cache categoryIDs"
        )
    }
}

// MARK: - Migration (US-12 / CL-19)

@Suite("V1 → V2 migration (MIGRATION.md rule 3)") struct MigrationTests {

    @Test func lightweightV1toV2OpensCleanly() throws {
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
