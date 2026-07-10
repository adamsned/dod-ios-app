import DODDomain
import Foundation
import Testing

@testable import DODNetworking

/// A single non-String element in JSON-LD `recipeIngredient` (a stray JSON
/// `null`, number, or nested object — real WPRM configs emit these for
/// ingredient-group headers) must cost only that one line, not the whole
/// list. `raw as? [String]` fails the ENTIRE cast when even one element
/// isn't a String, so before this fix a single malformed entry silently
/// dropped every real ingredient — mirrors the `mapVideo` DUT-214 fix for
/// the identical all-or-nothing cast failure mode.
@Suite("JSONLDRecipeParser.mapIngredients mixed-type tolerance")
struct JSONLDMapIngredientsMixedTypeTests {

    @Test func dropsOnlyTheNonStringElementNotTheWholeList() {
        let raw: [Any] = [
            "2 cups flour",
            NSNull(),
            "1 tsp salt",
        ]
        let mapped = JSONLDRecipeParser.mapIngredients(raw)
        #expect(mapped.map(\.text) == ["2 cups flour", "1 tsp salt"])
    }

    @Test func toleratesANestedGroupHeaderObject() {
        // Some WPRM ingredient-group configurations emit a bare `{...}` object
        // (a group-header marker) inside `recipeIngredient` alongside plain
        // string lines.
        let raw: [Any] = [
            ["name": "For the sauce"],
            "1 cup ketchup",
            42,
        ]
        let mapped = JSONLDRecipeParser.mapIngredients(raw)
        #expect(mapped.map(\.text) == ["1 cup ketchup"])
    }

    /// End-to-end: real JSON text decoded via `JSONSerialization` (matching how
    /// `JSONLDRecipeParser.parse` actually consumes a page's JSON-LD block) with
    /// a `null` entry mixed into `recipeIngredient`. Before the fix this
    /// produced ZERO ingredients for the whole recipe.
    @Test func parseKeepsGoodIngredientsWhenOneEntryIsNull() throws {
        let listItem = RecipeListItem(
            id: 1,
            title: "Mixed Ingredient Recipe",
            excerpt: "x",
            heroImage: nil,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: nil
        )
        let canonical =
            URL(string: "https://www.dutchovendaddy.com/mixed/")
            ?? URL(filePath: "/dev/null")
        let html = #"""
            <script type="application/ld+json">
            {
              "@context": "https://schema.org/",
              "@type": "Recipe",
              "name": "Mixed Ingredient Recipe",
              "recipeIngredient": ["2 cans corn", null, "2 tbsp butter"],
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
    }
}
