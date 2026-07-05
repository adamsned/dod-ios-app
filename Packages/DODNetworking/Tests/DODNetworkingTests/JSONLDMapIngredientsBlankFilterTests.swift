import DODDomain
import Foundation
import Testing

@testable import DODNetworking

/// DUT-587 — blank/whitespace JSON-LD ingredients must not become garbage
/// Shopping List rows. `mapIngredients` (the PRIMARY ingredient source) now
/// filters entries that are empty, whitespace-only, or sanitize to empty,
/// mirroring the WPRM card parser's non-empty guard.
@Suite("JSONLDRecipeParser.mapIngredients blank filter (DUT-587)")
struct JSONLDMapIngredientsBlankFilterTests {

    @Test func dropsEmptyAndWhitespaceOnlyEntries() {
        let mapped = JSONLDRecipeParser.mapIngredients([
            "2 cups flour",
            "",
            "   ",
            "\n\t ",
            "1 tsp salt",
        ])
        #expect(mapped.map(\.text) == ["2 cups flour", "1 tsp salt"])
    }

    @Test func dropsEntriesThatSanitizeToEmpty() {
        // An HTML comment / stray markup that `HTMLSanitizer.plainText` reduces
        // to empty must not survive as a blank row.
        let mapped = JSONLDRecipeParser.mapIngredients([
            "<!-- section header -->",
            "1 onion, diced",
        ])
        #expect(mapped.map(\.text) == ["1 onion, diced"])
    }

    @Test func keepsRealIngredientsUnchanged() {
        let mapped = JSONLDRecipeParser.mapIngredients(["3 lb beef chuck roast"])
        #expect(mapped.map(\.text) == ["3 lb beef chuck roast"])
    }

    /// End-to-end: a recipe whose JSON-LD `recipeIngredient` contains a blank
    /// entry produces NO blank ingredient (which would otherwise become a garbage
    /// "Other" Shopping List row).
    @Test func parseProducesNoBlankIngredientRow() throws {
        let listItem = RecipeListItem(
            id: 1,
            title: "Blank Ingredient Recipe",
            excerpt: "x",
            heroImage: nil,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: nil
        )
        let canonical =
            URL(string: "https://www.dutchovendaddy.com/blank/")
            ?? URL(filePath: "/dev/null")
        let html = #"""
            <script type="application/ld+json">
            {
              "@context": "https://schema.org/",
              "@type": "Recipe",
              "name": "Blank Ingredient Recipe",
              "recipeIngredient": ["2 cans corn", "", "   ", "2 tbsp butter"],
              "recipeInstructions": [{ "@type": "HowToStep", "text": "Cook." }]
            }
            </script>
            """#
        let recipe = try JSONLDRecipeParser.parse(
            html: html,
            merging: listItem,
            canonicalURL: canonical
        )
        #expect(recipe.ingredients.map(\.text) == ["2 cans corn", "2 tbsp butter"])
        #expect(
            !recipe.ingredients.contains {
                $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        )
    }
}
