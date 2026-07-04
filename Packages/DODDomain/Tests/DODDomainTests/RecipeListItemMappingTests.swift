import Foundation
import Testing

@testable import DODDomain

// DUT-534 Part 2 — the RecipeListItem → minimal Recipe mapping that lets a
// Feed/Search card feed the shared `ShoppingListAppender` (which hydrates the
// empty ingredients on append).

@Suite("Recipe(listItem:) mapping (DUT-534 Part 2)")
struct RecipeListItemMappingTests {

    @Test("Carries the list fields the hydration seam needs")
    func carriesListFields() {
        let canonical = URL(string: "https://www.dutchovendaddy.com/skillet-corn/")
        let published = Date(timeIntervalSince1970: 1_700_000_000)
        let item = RecipeListItem(
            id: 42,
            title: "Skillet Corn",
            excerpt: "Buttery.",
            heroImage: URL(string: "https://example.com/42.jpg"),
            publishedAt: published,
            canonicalURL: canonical,
            categoryIDs: [7, 9]
        )

        let recipe = Recipe(listItem: item)

        #expect(recipe.id == 42)
        #expect(recipe.title == "Skillet Corn")
        #expect(recipe.excerpt == "Buttery.")
        #expect(recipe.heroImage == URL(string: "https://example.com/42.jpg"))
        #expect(recipe.canonicalURL == canonical)
        #expect(recipe.categoryIDs == [7, 9])
        #expect(recipe.publishedAt == published)
        // Ingredients stay empty so the appender's hydrate-if-needed fetches them.
        #expect(recipe.ingredients.isEmpty)
    }

    @Test("nil canonicalURL / nil categoryIDs degrade cleanly")
    func nilFieldsDegrade() {
        let item = RecipeListItem(
            id: 1,
            title: "No URL",
            excerpt: "",
            publishedAt: Date(timeIntervalSince1970: 0)
            // canonicalURL + categoryIDs omitted → nil
        )

        let recipe = Recipe(listItem: item)

        // Non-optional canonicalURL is satisfied by the sentinel host fallback;
        // hydration against it simply yields no ingredients → `.couldntLoad`.
        #expect(recipe.canonicalURL.absoluteString == "https://www.dutchovendaddy.com/")
        #expect(recipe.categoryIDs.isEmpty)
        #expect(recipe.ingredients.isEmpty)
    }
}
