import DODDomain
import Foundation
import Testing

@testable import DODPersistence

/// DUT-592 protected `CachedRecipe.ingredientsJSON` from being clobbered by an
/// empty array on a partial/truncated recipe-kind re-parse (see
/// `MergeDetailNoEmptyClobberTests`), but `mergeDetail(_:)` rebuilds the
/// `CachedIngredient` search index from the RAW `recipe.ingredients` of the
/// current parse — not from what actually landed on `target.ingredientsJSON`.
/// So a re-parse that yields `[]` still unconditionally deletes every
/// `CachedIngredient` row for the recipe (`replaceIngredientIndexRows`),
/// silently breaking ingredient-name search (US-12 / DUT-11) for a recipe
/// whose cached ingredients are otherwise fully intact. These pin the index
/// staying in sync with the preserved (not clobbered) cached content.
@Suite("mergeDetail ingredient-index no-empty-clobber (DUT-592 follow-up)")
struct IngredientIndexNoEmptyClobberTests {

    private static let published = Date(timeIntervalSince1970: 1_700_000_000)

    private func recipe(id: Int, ingredients: [String]) -> Recipe {
        Recipe(
            id: id,
            slug: "slug-\(id)",
            title: "Title \(id)",
            excerpt: "Excerpt.",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/\(id)/") ?? URL(filePath: "/"),
            publishedAt: Self.published,
            ingredients: ingredients.map { .init(text: $0) }
        )
    }

    /// A recipe-kind re-parse with EMPTY ingredients must not wipe the
    /// ingredient search index for content that is still cached (unchanged,
    /// per DUT-592) on the recipe row.
    @Test func emptyReparseDoesNotWipeIngredientIndex() async throws {
        let store = try await makeStore()

        // First good parse populates both the cached JSON and the index.
        try await store.mergeDetail(recipe(id: 1, ingredients: ["4 cloves garlic", "1 lb pasta"]))
        #expect(try await store.ingredientIndexCount(forRecipeID: 1) == 2)
        #expect(try await store.searchIngredients(matching: "garlic") == [1])

        // A partial/truncated recipe-kind re-parse yields EMPTY ingredients.
        // `mergeDetail` preserves the cached `ingredientsJSON` (DUT-592) —
        // the index must stay consistent with that preserved content instead
        // of being wiped to zero rows.
        try await store.mergeDetail(recipe(id: 1, ingredients: []))

        let cached = try #require(try await store.recipe(id: 1))
        #expect(cached.ingredients.count == 2, "DUT-592: cached ingredients must survive an empty re-parse")

        #expect(
            try await store.ingredientIndexCount(forRecipeID: 1) == 2,
            "the ingredient index must stay in sync with the preserved cached ingredients, not the empty re-parse"
        )
        #expect(
            try await store.searchIngredients(matching: "garlic") == [1],
            "ingredient-name search must still find the recipe after an empty re-parse"
        )
    }
}
