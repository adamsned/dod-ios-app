import DODDomain
import Foundation
import Testing

@testable import DODNetworking

@Suite("JSONLDRecipeParser empty/nil/type arrays (adversarial)")
struct AdversarialEmptyAndTypeTests {

    @Test func emptyRecipeIngredientArray() {
        let raw: Any = []
        let ingredients = JSONLDRecipeParser.mapIngredients(raw)
        #expect(ingredients.isEmpty)
    }

    @Test func nilRecipeIngredient() {
        let ingredients = JSONLDRecipeParser.mapIngredients(nil)
        #expect(ingredients.isEmpty)
    }

    @Test func emptyRecipeInstructionsArray() {
        let raw: Any = []
        let instructions = JSONLDRecipeParser.mapInstructions(raw)
        #expect(instructions.isEmpty)
    }

    @Test func nilRecipeInstructions() {
        let instructions = JSONLDRecipeParser.mapInstructions(nil)
        #expect(instructions.isEmpty)
    }

    @Test func typeArrayWithMixedElements() {
        let object: [String: Any] = [
            "@type": ["Recipe", 123, NSNull()],
            "name": "Bread",
        ]
        let found = JSONLDRecipeParser.findRecipeObject(in: object)
        #expect(found?["name"] as? String == "Bread")
    }

    @Test func typeArrayWithOnlyNonStringElements() {
        let object: [String: Any] = [
            "@type": [123, NSNull(), true],
            "name": "NotARecipe",
        ]
        let found = JSONLDRecipeParser.findRecipeObject(in: object)
        #expect(found == nil)
    }

    @Test func typeAsNumberReturnsNil() {
        let object: [String: Any] = [
            "@type": 123,
            "name": "NotMatched",
        ]
        let found = JSONLDRecipeParser.findRecipeObject(in: object)
        #expect(found == nil)
    }

    @Test func typeAsObjectReturnsNil() {
        let object: [String: Any] = [
            "@type": ["nested": "object"],
            "name": "NotMatched",
        ]
        let found = JSONLDRecipeParser.findRecipeObject(in: object)
        #expect(found == nil)
    }
}

@Suite("JSONLDRecipeParser instructions (adversarial)")
struct AdversarialInstructionTests {

    @Test func howToStepWithOnlyNameField() {
        let raw: Any = [
            [
                "@type": "HowToStep",
                "name": "Preheat oven to 350F.",
            ]
        ]
        let steps = JSONLDRecipeParser.mapInstructions(raw)
        #expect(steps.count == 1)
        #expect(steps[0].text == "Preheat oven to 350F.")
    }

    @Test func howToStepWithNeitherTextNorName() {
        let raw: Any = [
            [
                "@type": "HowToStep",
                "duration": "PT5M",
            ]
        ]
        let steps = JSONLDRecipeParser.mapInstructions(raw)
        #expect(steps.isEmpty)
    }

    @Test func howToStepPrefersTextOverName() {
        let raw: Any = [
            [
                "@type": "HowToStep",
                "text": "From text field",
                "name": "From name field",
            ]
        ]
        let steps = JSONLDRecipeParser.mapInstructions(raw)
        #expect(steps.count == 1)
        #expect(steps[0].text == "From text field")
    }

    @Test func howToSectionWithEmptyItemListElement() {
        let raw: Any = [
            [
                "@type": "HowToSection",
                "name": "Prep",
                "itemListElement": [],
            ]
        ]
        let steps = JSONLDRecipeParser.mapInstructions(raw)
        #expect(steps.isEmpty)
    }

    @Test func howToSectionWithMissingItemListElement() {
        let raw: Any = [
            [
                "@type": "HowToSection",
                "name": "Prep",
            ]
        ]
        let steps = JSONLDRecipeParser.mapInstructions(raw)
        #expect(steps.isEmpty)
    }

    @Test func heterogeneousInstructionsStringAndHowToStepAndSection() {
        let raw: Any = [
            "Preheat oven.",
            [
                "@type": "HowToStep",
                "text": "Mix dry.",
            ],
            [
                "@type": "HowToSection",
                "name": "Bake",
                "itemListElement": [
                    ["@type": "HowToStep", "text": "Bake 30 min."],
                ],
            ],
            "Cool.",
        ]
        let steps = JSONLDRecipeParser.mapInstructions(raw)
        #expect(steps.count == 4)
        #expect(steps[0].text == "Preheat oven.")
        #expect(steps[1].text == "Mix dry.")
        #expect(steps[2].text == "Bake 30 min.")
        #expect(steps[3].text == "Cool.")
    }

    @Test func instructionWithUnknownTypeButHasTextField() {
        let raw: Any = [
            [
                "@type": "CustomStepType",
                "text": "Custom instruction.",
            ]
        ]
        let steps = JSONLDRecipeParser.mapInstructions(raw)
        #expect(steps.count == 1)
        #expect(steps[0].text == "Custom instruction.")
    }

    @Test func instructionWithUnknownTypeButNoTextReturnsEmpty() {
        let raw: Any = [
            [
                "@type": "CustomStepType",
                "description": "No text field.",
            ]
        ]
        let steps = JSONLDRecipeParser.mapInstructions(raw)
        #expect(steps.isEmpty)
    }
}

@Suite("JSONLDRecipeParser yield/video/ingredients (adversarial)")
struct AdversarialYieldVideoIngredientTests {

    @Test func recipeYieldZeroReturnsNil() {
        #expect(JSONLDRecipeParser.parseServings(0) == nil)
    }

    @Test func recipeYieldStringZeroReturnsNil() {
        #expect(JSONLDRecipeParser.parseServings("0") == nil)
    }

    @Test func recipeYieldNegativeReturnsNil() {
        #expect(JSONLDRecipeParser.parseServings(-5) == nil)
        #expect(JSONLDRecipeParser.parseServings("-3") == nil)
    }

    @Test func recipeYieldArrayWithZeroReturnsNil() {
        #expect(JSONLDRecipeParser.parseServings([0]) == nil)
    }

    @Test func recipeYieldArrayWithStringZeroReturnsNil() {
        #expect(JSONLDRecipeParser.parseServings(["0 servings"]) == nil)
    }

    @Test func videoArrayWithMultipleObjectsPicksFirst() {
        let raw: Any = [
            [
                "contentUrl": "https://example.com/first.mp4",
                "thumbnailUrl": "https://example.com/first.jpg",
            ],
            [
                "contentUrl": "https://example.com/second.mp4",
                "thumbnailUrl": "https://example.com/second.jpg",
            ],
        ]
        let video = JSONLDRecipeParser.mapVideo(raw)
        #expect(video?.url.absoluteString == "https://example.com/first.mp4")
    }

    @Test func videoWithEmptyStringContentUrlFallsBackToEmbedUrl() {
        let raw: [String: Any] = [
            "contentUrl": "",
            "embedUrl": "https://example.com/embed.html",
        ]
        let video = JSONLDRecipeParser.mapVideo(raw)
        #expect(video?.url.absoluteString == "https://example.com/embed.html")
    }

    @Test func videoWithBothEmptyStringsReturnsNil() {
        let raw: [String: Any] = [
            "contentUrl": "",
            "embedUrl": "",
        ]
        let video = JSONLDRecipeParser.mapVideo(raw)
        #expect(video == nil)
    }

    @Test func videoArrayWithNonDictElementsSkipsNonDicts() {
        let raw: Any = [
            "string reference",
            [
                "contentUrl": "https://example.com/video.mp4",
            ],
            123,
        ]
        let video = JSONLDRecipeParser.mapVideo(raw)
        #expect(video?.url.absoluteString == "https://example.com/video.mp4")
    }

    @Test func videoArrayWithNoValidDictReturnsNil() {
        let raw: Any = ["invalid", 123, ["noUrl": "here"]]
        let video = JSONLDRecipeParser.mapVideo(raw)
        #expect(video == nil)
    }

    @Test func ingredientWithHTMLEntities() {
        let raw: Any = [
            "2&nbsp;cups flour",
            "1&frac12; teaspoons salt",
            "&lt;tag&gt;",
        ]
        let ingredients = JSONLDRecipeParser.mapIngredients(raw)
        #expect(ingredients.count == 3)
        #expect(!ingredients.contains { $0.text.contains("&") })
    }

    @Test func ingredientWhitespaceOnlyIsDropped() {
        let raw: Any = [
            "   ",
            "\t\n",
            "1 cup flour",
        ]
        let ingredients = JSONLDRecipeParser.mapIngredients(raw)
        #expect(ingredients.count == 1)
        #expect(ingredients[0].text == "1 cup flour")
    }

    @Test func ingredientArrayWithNonStringElementsKeepsStringsOnly() {
        let raw: Any = [
            "2 cups flour",
            123,
            NSNull(),
            "1 egg",
            ["nested": "object"],
        ]
        let ingredients = JSONLDRecipeParser.mapIngredients(raw)
        #expect(ingredients.count == 2)
        #expect(ingredients.map(\.text) == ["2 cups flour", "1 egg"])
    }
}

@Suite("JSONLDRecipeParser @graph/duration (adversarial)")
struct AdversarialGraphAndDurationTests {

    @Test func recipeInsideGraphInsideGraph() {
        let object: [String: Any] = [
            "@graph": [
                [
                    "@graph": [
                        ["@type": "Recipe", "name": "Nested"],
                        ["@type": "Article"],
                    ]
                ],
                ["@type": "WebPage"],
            ]
        ]
        let found = JSONLDRecipeParser.findRecipeObject(in: object)
        #expect(found?["name"] as? String == "Nested")
    }

    @Test func graphContainsArrayOfRecipesReturnsFirst() {
        let object: [String: Any] = [
            "@graph": [
                ["@type": "Recipe", "name": "First"],
                ["@type": "Recipe", "name": "Second"],
            ]
        ]
        let found = JSONLDRecipeParser.findRecipeObject(in: object)
        #expect(found?["name"] as? String == "First")
    }

    @Test func graphWithOnlyArticleDoesNotMatchRecipe() {
        let object: [String: Any] = [
            "@graph": [
                ["@type": "Article", "headline": "Not a recipe"],
                ["@type": "WebPage"],
            ]
        ]
        let found = JSONLDRecipeParser.findRecipeObject(in: object)
        #expect(found == nil)
    }

    @Test func graphWithItemListDoesNotMatchRecipe() {
        let object: [String: Any] = [
            "@graph": [
                [
                    "@type": "ItemList",
                    "itemListElement": [
                        ["name": "Item 1"],
                        ["name": "Item 2"],
                    ],
                ],
            ]
        ]
        let found = JSONLDRecipeParser.findRecipeObject(in: object)
        #expect(found == nil)
    }

    @Test func durationWithTrailingDigitAndNoUnitReturnsNil() {
        #expect(JSONLDRecipeParser.parseISO8601Duration("PT15M30") == nil)
    }

    @Test func durationWithInvalidUnitBeforeTimePartReturnsNil() {
        #expect(JSONLDRecipeParser.parseISO8601Duration("P15MT10M") == nil)
    }

    @Test func durationWithoutPPrefixReturnsNil() {
        #expect(JSONLDRecipeParser.parseISO8601Duration("T15M") == nil)
    }

    @Test func durationWithOnlyPReturnsNil() {
        #expect(JSONLDRecipeParser.parseISO8601Duration("P") == nil)
    }

    @Test func durationWithDoubleTIsLenientAndParsesSecondT() {
        #expect(JSONLDRecipeParser.parseISO8601Duration("PTT15M") == .seconds(900))
    }
}
