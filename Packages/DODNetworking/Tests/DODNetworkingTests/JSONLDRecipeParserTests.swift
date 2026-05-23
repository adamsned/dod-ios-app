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
        #expect(JSONLDRecipeParser.parseServings("8") == 8)
        #expect(JSONLDRecipeParser.parseServings("6 servings") == 6)
        #expect(JSONLDRecipeParser.parseServings(["4"]) == 4)
        #expect(JSONLDRecipeParser.parseServings(nil) == nil)
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
}
