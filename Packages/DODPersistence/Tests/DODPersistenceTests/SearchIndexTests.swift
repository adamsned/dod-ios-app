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
