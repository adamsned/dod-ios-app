import DODDomain
import Foundation
import Testing

@testable import DODNetworking

/// Field-shape coverage for the DUT-572 / CL-310 editorial info fields
/// (Course / Cuisine / Diet / Author) mapped by `JSONLDRecipeParser`.
@Suite("JSONLDRecipeParser.mapStringOrArray (Course/Cuisine/Diet)")
struct MapStringOrArrayTests {

    @Test func bareString() {
        #expect(JSONLDRecipeParser.mapStringOrArray("Dessert") == ["Dessert"])
    }

    @Test func stringArray() {
        let raw: Any = ["Dinner", "Main Course"]
        #expect(JSONLDRecipeParser.mapStringOrArray(raw) == ["Dinner", "Main Course"])
    }

    @Test func arrayOfNameObjects() {
        let raw: Any = [
            ["@type": "Thing", "name": "Italian"],
            ["@type": "Thing", "name": "Mediterranean"],
        ]
        #expect(JSONLDRecipeParser.mapStringOrArray(raw) == ["Italian", "Mediterranean"])
    }

    @Test func mixedStringAndNameObjects() {
        let raw: Any = ["Vegan", ["name": "Gluten Free"]]
        #expect(JSONLDRecipeParser.mapStringOrArray(raw) == ["Vegan", "Gluten Free"])
    }

    @Test func htmlIsStripped() {
        #expect(JSONLDRecipeParser.mapStringOrArray("<em>Breakfast</em>") == ["Breakfast"])
    }

    @Test func dietSchemaOrgURLStoredRaw() {
        // suitableForDiet is frequently a schema.org URL — stored verbatim;
        // display-time prettifying is the UI's job.
        let raw: Any = ["https://schema.org/LowFatDiet", "https://schema.org/VeganDiet"]
        #expect(
            JSONLDRecipeParser.mapStringOrArray(raw)
                == ["https://schema.org/LowFatDiet", "https://schema.org/VeganDiet"]
        )
    }

    @Test func absentReturnsEmpty() {
        #expect(JSONLDRecipeParser.mapStringOrArray(nil).isEmpty)
    }

    @Test func unrecognizedShapeReturnsEmpty() {
        #expect(JSONLDRecipeParser.mapStringOrArray(42).isEmpty)
    }

    @Test func emptyStringDropped() {
        #expect(JSONLDRecipeParser.mapStringOrArray("").isEmpty)
    }
}

@Suite("JSONLDRecipeParser.mapAuthorName")
struct MapAuthorNameTests {

    @Test func personDict() {
        let raw: Any = ["@type": "Person", "name": "Jane Cook"]
        #expect(JSONLDRecipeParser.mapAuthorName(raw) == "Jane Cook")
    }

    @Test func organizationDict() {
        let raw: Any = ["@type": "Organization", "name": "Dutch Oven Daddy"]
        #expect(JSONLDRecipeParser.mapAuthorName(raw) == "Dutch Oven Daddy")
    }

    @Test func bareString() {
        #expect(JSONLDRecipeParser.mapAuthorName("Ned Adams") == "Ned Adams")
    }

    @Test func arrayTakesFirstNamed() {
        let raw: Any = [
            ["@type": "Person", "name": "First Author"],
            ["@type": "Person", "name": "Second Author"],
        ]
        #expect(JSONLDRecipeParser.mapAuthorName(raw) == "First Author")
    }

    @Test func arraySkipsUnnamedThenTakesNamed() {
        let raw: Any = [["@type": "Person"], ["@type": "Person", "name": "Real Author"]]
        #expect(JSONLDRecipeParser.mapAuthorName(raw) == "Real Author")
    }

    @Test func htmlIsStripped() {
        let raw: Any = ["@type": "Person", "name": "<b>Bold</b> Chef"]
        #expect(JSONLDRecipeParser.mapAuthorName(raw) == "Bold Chef")
    }

    @Test func absentReturnsNil() {
        #expect(JSONLDRecipeParser.mapAuthorName(nil) == nil)
    }

    @Test func dictWithoutNameReturnsNil() {
        let raw: Any = ["@type": "Person", "url": "https://example.com"]
        #expect(JSONLDRecipeParser.mapAuthorName(raw) == nil)
    }

    @Test func emptyNameReturnsNil() {
        let raw: Any = ["@type": "Person", "name": ""]
        #expect(JSONLDRecipeParser.mapAuthorName(raw) == nil)
    }
}

/// End-to-end: the four fields land on the parsed `Recipe` via `mapRecipe`,
/// and are absent-safe (empty / nil) when the JSON-LD omits them.
@Suite("JSONLDRecipeParser info fields end-to-end (DUT-572)")
struct RecipeInfoFieldsEndToEndTests {

    private static let listItem = RecipeListItem(
        id: 7,
        title: "Test",
        excerpt: "",
        heroImage: nil,
        publishedAt: .distantPast
    )
    private static let canonical =
        URL(string: "https://example.com/test") ?? URL(filePath: "/dev/null")

    @Test func populatesAllFourFields() {
        let jsonLD: [String: Any] = [
            "@type": "Recipe",
            "recipeCategory": "Dinner",
            "recipeCuisine": ["Italian"],
            "suitableForDiet": ["https://schema.org/LowFatDiet"],
            "author": ["@type": "Person", "name": "Chef Ned"],
        ]
        let recipe = JSONLDRecipeParser.mapRecipe(
            jsonLD: jsonLD,
            listItem: Self.listItem,
            canonicalURL: Self.canonical,
            html: ""
        )
        #expect(recipe.recipeCategory == ["Dinner"])
        #expect(recipe.recipeCuisine == ["Italian"])
        #expect(recipe.suitableForDiet == ["https://schema.org/LowFatDiet"])
        #expect(recipe.author == "Chef Ned")
    }

    @Test func absentFieldsDefaultToEmptyAndNil() {
        let jsonLD: [String: Any] = ["@type": "Recipe", "name": "Bare"]
        let recipe = JSONLDRecipeParser.mapRecipe(
            jsonLD: jsonLD,
            listItem: Self.listItem,
            canonicalURL: Self.canonical,
            html: ""
        )
        #expect(recipe.recipeCategory.isEmpty)
        #expect(recipe.recipeCuisine.isEmpty)
        #expect(recipe.suitableForDiet.isEmpty)
        #expect(recipe.author == nil)
    }
}

@Suite("JSONLDRecipeParser.parseServings array/non-positive (DUT-610)")
struct ParseServingsArrayTests {

    /// The array branch must apply the same unit-word split fallback as the
    /// string branch, accept a numeric element, and treat a non-positive yield
    /// as absent. Previously `["6 servings"]` returned nil and silently
    /// mis-scaled every ingredient in the detail view.
    @Test func parsesArrayAndRejectsNonPositive() {
        #expect(JSONLDRecipeParser.parseServings(["6 servings"]) == 6)
        #expect(JSONLDRecipeParser.parseServings(["4", "4 servings"]) == 4)
        #expect(JSONLDRecipeParser.parseServings([8]) == 8)
        #expect(JSONLDRecipeParser.parseServings("0") == nil)
        #expect(JSONLDRecipeParser.parseServings(0) == nil)
    }
}

@Suite("JSONLDRecipeParser.mapNutrition sanitization (DUT-612)")
struct MapNutritionSanitizationTests {

    /// Nutrition string fields must be HTML-sanitized like every sibling
    /// mapper, so entities such as `250&nbsp;kcal` render as plain text and a
    /// missing field stays `nil` rather than sanitizing into `""`.
    @Test func sanitizesNutritionFields() {
        let nutrition = JSONLDRecipeParser.mapNutrition([
            "calories": "250&nbsp;kcal", "proteinContent": "12&amp;g",
        ])
        #expect(nutrition?.calories == "250 kcal")
        #expect(nutrition?.proteinGrams == "12&g")
        #expect(nutrition?.servingSize == nil)
    }
}
