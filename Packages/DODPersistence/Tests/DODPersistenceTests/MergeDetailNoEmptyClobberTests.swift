import DODDomain
import Foundation
import Testing

@testable import DODPersistence

/// DUT-592 (Low–Medium) — `mergeDetail` unconditionally overwrote
/// `ingredientsJSON`/`instructionsJSON`, so a recipe-kind re-parse that yielded
/// an empty `ingredients` array (a WPRM markup change, a throttled/truncated
/// fetch, an unhandled JSON-LD variant) wiped the previously-cached
/// ingredients/instructions — including for a saved/downloaded recipe the user
/// expects fully usable offline (AC-4.9 / AC-5.2). The fix mirrors the DUT-399
/// don't-clobber-with-empty guards: for `.recipe`, only overwrite when the parse
/// actually produced content. `.article` (which legitimately has none) still
/// clears unconditionally. These pin both halves.
@Suite("mergeDetail no-empty-clobber (DUT-592)")
struct MergeDetailNoEmptyClobberTests {

    private static let published = Date(timeIntervalSince1970: 1_700_000_000)

    private func recipe(
        id: Int,
        kind: PostKind,
        ingredients: [String],
        instructions: [String]
    ) -> Recipe {
        Recipe(
            id: id,
            slug: "slug-\(id)",
            title: "Title \(id)",
            excerpt: "Excerpt.",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/\(id)/") ?? URL(filePath: "/"),
            publishedAt: Self.published,
            ingredients: ingredients.map { .init(text: $0) },
            instructions: instructions.enumerated().map { .init(step: $0.offset + 1, text: $0.element) },
            kind: kind,
            // A non-empty body makes an `.article` reconstruct as `.article` on read.
            articleBodyHTML: kind == .article ? "<p>Body</p>" : nil
        )
    }

    /// A recipe-kind re-parse with EMPTY ingredients/instructions must NOT wipe
    /// the previously-cached non-empty values — the offline-usability regression.
    @Test func recipeReparseWithEmptyDoesNotWipeCachedIngredients() async throws {
        let store = try await makeStore()

        // First good parse populates ingredients + instructions.
        try await store.mergeDetail(
            recipe(id: 1, kind: .recipe, ingredients: ["2 cups flour", "1 egg"], instructions: ["Mix.", "Bake."])
        )
        let afterGood = try #require(try await store.recipe(id: 1))
        #expect(afterGood.ingredients.count == 2)
        #expect(afterGood.instructions.count == 2)

        // A partial/truncated recipe-kind re-parse yields EMPTY content.
        try await store.mergeDetail(
            recipe(id: 1, kind: .recipe, ingredients: [], instructions: [])
        )

        // The cached content is preserved, not clobbered with `[]`.
        let afterEmpty = try #require(try await store.recipe(id: 1))
        #expect(afterEmpty.ingredients.count == 2, "empty re-parse must not wipe cached ingredients")
        #expect(afterEmpty.instructions.count == 2, "empty re-parse must not wipe cached instructions")
    }

    /// A recipe-kind re-parse that DOES yield content still overwrites — the
    /// guard is empty-only, not a freeze.
    @Test func recipeReparseWithContentStillOverwrites() async throws {
        let store = try await makeStore()

        try await store.mergeDetail(
            recipe(id: 2, kind: .recipe, ingredients: ["old"], instructions: ["old step"])
        )
        try await store.mergeDetail(
            recipe(id: 2, kind: .recipe, ingredients: ["new a", "new b"], instructions: ["new 1"])
        )

        let updated = try #require(try await store.recipe(id: 2))
        #expect(updated.ingredients.map(\.text) == ["new a", "new b"])
        #expect(updated.instructions.map(\.text) == ["new 1"])
    }

    /// An `.article` re-parse still CLEARS ingredients/instructions
    /// unconditionally — an article legitimately has none, so the empty write is
    /// correct there (unchanged behavior).
    @Test func articleReparseStillClearsIngredients() async throws {
        let store = try await makeStore()

        // Seed as a recipe with content...
        try await store.mergeDetail(
            recipe(id: 3, kind: .recipe, ingredients: ["1 cup sugar"], instructions: ["Stir."])
        )
        #expect(try #require(try await store.recipe(id: 3)).ingredients.count == 1)

        // ...then a later parse classifies it as an article: content clears.
        try await store.mergeDetail(
            recipe(id: 3, kind: .article, ingredients: [], instructions: [])
        )

        let asArticle = try #require(try await store.recipe(id: 3))
        #expect(asArticle.kind == .article)
        #expect(asArticle.ingredients.isEmpty, "an article must clear cached ingredients")
        #expect(asArticle.instructions.isEmpty, "an article must clear cached instructions")
    }
}
