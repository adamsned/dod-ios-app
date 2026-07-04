import DODDomain
import Foundation
import Testing

@testable import DODNetworking

@Suite("JSONLDRecipeParser.extractJSONLDBlocks (T-057)") struct ExtractBlocksTests {

    @Test func returnsEmptyForNoBlocks() {
        let html = "<html><body><p>no scripts here</p></body></html>"
        #expect(JSONLDRecipeParser.extractJSONLDBlocks(in: html).isEmpty)
    }

    @Test func ignoresNonJSONLDScripts() {
        let html = """
            <script>var x = 1;</script>
            <script type="application/json">{"a":1}</script>
            <script type="application/ld+json">{"@type":"Thing"}</script>
            """
        let blocks = JSONLDRecipeParser.extractJSONLDBlocks(in: html)
        #expect(blocks.count == 1)
        #expect(blocks.first?.contains("Thing") == true)
    }

    @Test func extractsMultipleJSONLDBlocks() {
        let html = """
            <script type="application/ld+json">{"@type":"Article"}</script>
            <p>between</p>
            <script type="application/ld+json">{"@type":"Recipe"}</script>
            """
        let blocks = JSONLDRecipeParser.extractJSONLDBlocks(in: html)
        #expect(blocks.count == 2)
    }

    @Test func attributeOrderDoesntMatter() {
        let html = #"<script id="x" type="application/ld+json" data-foo="bar">{"a":1}</script>"#
        let blocks = JSONLDRecipeParser.extractJSONLDBlocks(in: html)
        #expect(blocks.count == 1)
    }
}

@Suite("JSONLDRecipeParser.findRecipeObject (T-058)") struct FindRecipeTests {

    @Test func findsDirectRecipeObject() {
        let object: [String: Any] = ["@type": "Recipe", "name": "Bread"]
        let found = JSONLDRecipeParser.findRecipeObject(in: object)
        #expect(found?["name"] as? String == "Bread")
    }

    @Test func findsRecipeInsideGraph() {
        let object: [String: Any] = [
            "@graph": [
                ["@type": "WebPage"],
                ["@type": "Recipe", "name": "Pasta"],
            ]
        ]
        let found = JSONLDRecipeParser.findRecipeObject(in: object)
        #expect(found?["name"] as? String == "Pasta")
    }

    @Test func findsRecipeWithTypeArray() {
        let object: [String: Any] = ["@type": ["Recipe", "BlogPosting"], "name": "Cake"]
        let found = JSONLDRecipeParser.findRecipeObject(in: object)
        #expect(found?["name"] as? String == "Cake")
    }

    @Test func returnsNilWhenNoRecipePresent() {
        let object: [String: Any] = ["@type": "Article"]
        #expect(JSONLDRecipeParser.findRecipeObject(in: object) == nil)
    }
}

@Suite("JSONLDRecipeParser.mapInstructions (T-059)") struct InstructionShapeTests {

    @Test func stringArrayShape() {
        let raw: Any = ["Preheat oven.", "Stir.", "Bake."]
        let steps = JSONLDRecipeParser.mapInstructions(raw)
        #expect(steps.map(\.step) == [1, 2, 3])
        #expect(steps[1].text == "Stir.")
    }

    @Test func howToStepArrayShape() {
        let raw: Any = [
            ["@type": "HowToStep", "text": "Mix dry ingredients."],
            ["@type": "HowToStep", "text": "Add wet."],
        ]
        let steps = JSONLDRecipeParser.mapInstructions(raw)
        #expect(steps.count == 2)
        #expect(steps[0].text == "Mix dry ingredients.")
    }

    @Test func howToSectionShape() {
        let raw: Any = [
            [
                "@type": "HowToSection",
                "name": "Prep",
                "itemListElement": [
                    ["@type": "HowToStep", "text": "Chop onions."]
                ],
            ],
            [
                "@type": "HowToSection",
                "name": "Cook",
                "itemListElement": [
                    ["@type": "HowToStep", "text": "Sauté."],
                    ["@type": "HowToStep", "text": "Simmer."],
                ],
            ],
        ]
        let steps = JSONLDRecipeParser.mapInstructions(raw)
        #expect(steps.count == 3)
        #expect(steps[0].text == "Chop onions.")
        #expect(steps[2].text == "Simmer.")
    }

    @Test func htmlIsStrippedFromStepText() {
        let raw: Any = ["<strong>Bold</strong> instructions."]
        let steps = JSONLDRecipeParser.mapInstructions(raw)
        #expect(steps[0].text == "Bold instructions.")
    }
}

@Suite("JSONLDRecipeParser misc helpers") struct HelperTests {

    @Test func parsesISO8601Durations() {
        #expect(JSONLDRecipeParser.parseISO8601Duration("PT15M") == .seconds(15 * 60))
        #expect(JSONLDRecipeParser.parseISO8601Duration("PT1H30M") == .seconds(90 * 60))
        #expect(JSONLDRecipeParser.parseISO8601Duration("PT2H") == .seconds(2 * 3600))
        #expect(JSONLDRecipeParser.parseISO8601Duration(nil) == nil)
        #expect(JSONLDRecipeParser.parseISO8601Duration("garbage") == nil)
    }

    @Test func parsesServingsFromMultipleShapes() {
        #expect(JSONLDRecipeParser.parseServings(4) == 4)
        #expect(JSONLDRecipeParser.parseServings(4.0) == 4)
        #expect(JSONLDRecipeParser.parseServings("8") == 8)
        #expect(JSONLDRecipeParser.parseServings("6 servings") == 6)
        #expect(JSONLDRecipeParser.parseServings("4 servings") == 4)
        #expect(JSONLDRecipeParser.parseServings(["4"]) == 4)
        #expect(JSONLDRecipeParser.parseServings(nil) == nil)
    }

    /// DUT-518 — `recipeYield` arrives as an untrusted `Double` from scraped
    /// JSON-LD. `Int(Double)` traps on out-of-range/non-finite values, so a
    /// giant or infinite yield must return nil instead of crashing.
    @Test func rejectsOutOfRangeDoubleServingsWithoutCrashing() {
        #expect(JSONLDRecipeParser.parseServings(1e30) == nil)
        #expect(JSONLDRecipeParser.parseServings(1e400) == nil)  // parses to .infinity
        #expect(JSONLDRecipeParser.parseServings(Double.infinity) == nil)
        #expect(JSONLDRecipeParser.parseServings(Double.nan) == nil)
    }
}

@Suite("JSONLDRecipeParser.parse end-to-end") struct ParseTests {

    private static let listItem = RecipeListItem(
        id: 42,
        title: "Test Recipe",
        excerpt: "Tasty.",
        heroImage: nil,
        publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
        totalTimeDisplay: nil
    )

    private static let canonical =
        URL(string: "https://www.dutchovendaddy.com/test-recipe/")
        ?? URL(filePath: "/dev/null")

    @Test func throwsWhenNoBlocks() {
        let html = "<html><body>just text</body></html>"
        #expect(throws: JSONLDRecipeParser.Error.noJSONLDBlocks) {
            _ = try JSONLDRecipeParser.parse(html: html, merging: Self.listItem, canonicalURL: Self.canonical)
        }
    }

    @Test func throwsWhenNoRecipeFound() {
        let html = #"""
            <script type="application/ld+json">{"@type":"Article","headline":"Not a recipe"}</script>
            """#
        #expect(throws: JSONLDRecipeParser.Error.notFound) {
            _ = try JSONLDRecipeParser.parse(html: html, merging: Self.listItem, canonicalURL: Self.canonical)
        }
    }

    @Test func parsesCompleteRecipe() throws {
        let html = #"""
            <script type="application/ld+json">
            {
              "@context": "https://schema.org/",
              "@type": "Recipe",
              "name": "Skillet Corn",
              "prepTime": "PT5M",
              "cookTime": "PT10M",
              "totalTime": "PT15M",
              "recipeYield": "4",
              "recipeIngredient": ["2 cans corn", "2 tbsp butter"],
              "recipeInstructions": [
                { "@type": "HowToStep", "text": "Melt butter." },
                { "@type": "HowToStep", "text": "Add corn." }
              ],
              "nutrition": {
                "@type": "NutritionInformation",
                "calories": "210 kcal",
                "proteinContent": "5g"
              },
              "video": {
                "@type": "VideoObject",
                "contentUrl": "https://example.com/v.mp4",
                "thumbnailUrl": "https://example.com/t.jpg",
                "duration": "PT2M30S"
              }
            }
            </script>
            """#

        let recipe = try JSONLDRecipeParser.parse(
            html: html,
            merging: Self.listItem,
            canonicalURL: Self.canonical
        )
        #expect(recipe.ingredients.count == 2)
        #expect(recipe.instructions.count == 2)
        #expect(recipe.instructions[1].text == "Add corn.")
        #expect(recipe.prepTime == .seconds(5 * 60))
        #expect(recipe.totalTime == .seconds(15 * 60))
        #expect(recipe.servings == 4)
        #expect(recipe.nutrition?.calories == "210 kcal")
        #expect(recipe.video?.duration == .seconds(150))
    }

    /// DUT-509: the parsed `Recipe` must carry the merged `RecipeListItem`'s
    /// `categoryIDs` so `loadRelated(forCategoryID:)` has a category on the very
    /// first parse — before the fix `mapRecipe` hard-coded `categoryIDs: []`, so
    /// the related-recipes strip stayed empty until a later cache reconcile.
    @Test func carriesListItemCategoryIDs() throws {
        let listItem = RecipeListItem(
            id: 42,
            title: "Test Recipe",
            excerpt: "Tasty.",
            heroImage: nil,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: nil,
            categoryIDs: [336, 1590]
        )
        let html = #"""
            <script type="application/ld+json">
            {"@context":"https://schema.org/","@type":"Recipe","name":"Skillet Corn",
             "recipeIngredient":["2 cans corn"],
             "recipeInstructions":[{"@type":"HowToStep","text":"Cook."}]}
            </script>
            """#

        let recipe = try JSONLDRecipeParser.parse(
            html: html,
            merging: listItem,
            canonicalURL: Self.canonical
        )
        #expect(recipe.categoryIDs == [336, 1590])
    }

    /// DUT-509: a `RecipeListItem` with no `categoryIDs` (nil) still yields an
    /// empty array rather than crashing — the `?? []` fallback holds.
    @Test func absentCategoryIDsDefaultToEmpty() throws {
        let html = #"""
            <script type="application/ld+json">
            {"@context":"https://schema.org/","@type":"Recipe","name":"Skillet Corn",
             "recipeIngredient":["2 cans corn"],
             "recipeInstructions":[{"@type":"HowToStep","text":"Cook."}]}
            </script>
            """#

        let recipe = try JSONLDRecipeParser.parse(
            html: html,
            merging: Self.listItem,
            canonicalURL: Self.canonical
        )
        #expect(recipe.categoryIDs.isEmpty)
    }
}

@Suite("JSONLDRecipeParser WPRM card fallback (DUT-42)") struct WPRMFallbackTests {

    private static let listItem = RecipeListItem(
        id: 563,
        title: "Dutch Oven 7 Can Soup",
        excerpt: "Pantry soup.",
        heroImage: nil,
        publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
        totalTimeDisplay: nil
    )

    private static let canonical =
        URL(string: "https://www.dutchovendaddy.com/dutch-oven-7-can-soup/")
        ?? URL(filePath: "/dev/null")

    /// DUT-42 reproduction. The `seven-can-soup.html` fixture is a trimmed-but-
    /// real capture whose JSON-LD `Recipe` node OMITS `recipeIngredient` /
    /// `recipeInstructions`. Pre-fix this parsed to an EMPTY ingredient list;
    /// the WPRM fallback recovers the ingredients from the card's
    /// `wprm-recipe-ingredient-group-name` headers (this post's real shape).
    @Test func recoversIngredientsFromWPRMCardWhenJSONLDOmitsThem() throws {
        let html = try loadFixture("seven-can-soup")
        let recipe = try JSONLDRecipeParser.parse(
            html: html,
            merging: Self.listItem,
            canonicalURL: Self.canonical
        )
        let texts = recipe.ingredients.map(\.text).joined(separator: "|").lowercased()
        #expect(texts.contains("black beans") && texts.contains("corn") && texts.contains("pinto beans"))
        // DUT-538: the WPRM card has no `wprm-recipe-instruction` rows — the
        // steps live in the post body's "How to Make" numbered-step lists, and
        // the fallback recovers all 4 (per-step text covered by the DODSupport
        // WPRMRecipeCardParser unit tests) rather than dumping the article body.
        #expect(recipe.instructions.map(\.step) == [1, 2, 3, 4], "should recover 4 How-to-Make steps")
        #expect(recipe.instructions.first?.text.localizedCaseInsensitiveContains("Open and Dump") == true)
        // The JSON-LD times/yield/nutrition still parse normally — the fallback
        // is per-field and does not disturb the fields JSON-LD did provide.
        #expect(recipe.totalTime == .seconds(20 * 60))
        #expect(recipe.servings == 10)
        #expect(recipe.nutrition?.calories == "291 kcal")
    }

    /// End-to-end proof that the fallback also recovers INSTRUCTIONS through
    /// `parse(...)` when the JSON-LD omits them but the WPRM card carries the
    /// standard `wprm-recipe-ingredient` line rows + `wprm-recipe-instruction`
    /// rows (the common shape across the catalog — real markup from
    /// `dutch-oven-awesome-chili`).
    @Test func recoversBothListsFromStandardWPRMCard() throws {
        let html = """
            <html><head>
            <script type="application/ld+json">
            {"@context":"https://schema.org/","@type":"Recipe","name":"Standard Card","totalTime":"PT30M"}
            </script>
            </head><body>
            <div class="entry-content">
            <div class="wprm-recipe-container">
            <ul class="wprm-recipe-ingredients">
            <li class="wprm-recipe-ingredient"><span class="wprm-checkbox-container"><label><span class="wprm-screen-reader-text">&#9634; </span></label></span><span class="wprm-recipe-ingredient-amount">3</span> <span class="wprm-recipe-ingredient-unit">lbs</span> <span class="wprm-recipe-ingredient-name">lean ground beef</span></li>
            <li class="wprm-recipe-ingredient"><span class="wprm-recipe-ingredient-amount">1</span> <span class="wprm-recipe-ingredient-name">onion</span> <span class="wprm-recipe-ingredient-notes">diced</span></li>
            </ul>
            <ul class="wprm-recipe-instructions">
            <li class="wprm-recipe-instruction"><div class="wprm-recipe-instruction-text"><span style="display: block;">Heat the Dutch oven over medium-high heat</span></div></li>
            <li class="wprm-recipe-instruction"><div class="wprm-recipe-instruction-text"><span style="display: block;">Crumble in the ground beef; stir.</span></div></li>
            </ul>
            </div>
            </div>
            </body></html>
            """
        let recipe = try JSONLDRecipeParser.parse(
            html: html,
            merging: Self.listItem,
            canonicalURL: Self.canonical
        )
        #expect(recipe.ingredients.map(\.text) == ["3 lbs lean ground beef", "1 onion diced"])
        #expect(
            recipe.instructions.map(\.text) == [
                "Heat the Dutch oven over medium-high heat", "Crumble in the ground beef; stir.",
            ]
        )
        #expect(recipe.instructions.map(\.step) == [1, 2])
    }

    /// Regression guard: a recipe with COMPLETE JSON-LD ingredients +
    /// instructions is unchanged — the WPRM card is not consulted (even if one
    /// is present), so good JSON-LD always wins.
    @Test func completeJSONLDIsUnchangedByFallback() throws {
        let html = """
            <html><head>
            <script type="application/ld+json">
            {"@context":"https://schema.org/","@type":"Recipe","name":"Good","totalTime":"PT15M",
             "recipeIngredient":["2 cans corn","2 tbsp butter"],
             "recipeInstructions":[{"@type":"HowToStep","text":"Melt butter."},{"@type":"HowToStep","text":"Add corn."}]}
            </script>
            </head><body>
            <div class="wprm-recipe-container">
            <ul class="wprm-recipe-ingredients">
            <li class="wprm-recipe-ingredient"><span class="wprm-recipe-ingredient-name">SHOULD NOT APPEAR</span></li>
            </ul>
            </div>
            </body></html>
            """
        let recipe = try JSONLDRecipeParser.parse(
            html: html,
            merging: Self.listItem,
            canonicalURL: Self.canonical
        )
        #expect(recipe.ingredients.map(\.text) == ["2 cans corn", "2 tbsp butter"])
        #expect(recipe.instructions.map(\.text) == ["Melt butter.", "Add corn."])
        #expect(!recipe.ingredients.contains { $0.text.contains("SHOULD NOT APPEAR") })
    }

    private func loadFixture(_ name: String) throws -> String {
        let url = try #require(
            Bundle.module.url(forResource: name, withExtension: "html"),
            "Fixture \(name).html not found in test bundle"
        )
        return try String(contentsOf: url, encoding: .utf8)
    }
}
