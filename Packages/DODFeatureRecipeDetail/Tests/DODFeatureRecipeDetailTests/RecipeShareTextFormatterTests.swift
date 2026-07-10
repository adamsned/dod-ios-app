import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// DUT-889 — pure-formatter coverage for the "Share as Text" plain-text
/// builder. `RecipeShareTextFormatter` has no SwiftUI dependency, so these
/// exercise it directly against `Recipe` fixtures.
@Suite("RecipeShareTextFormatter (DUT-889)") struct RecipeShareTextFormatterTests {

    @Test func formatsFullRecipe() throws {
        let ingredients = [
            RecipeIngredient(id: UUID(), text: "1 lb ground beef"),
            RecipeIngredient(id: UUID(), text: "1 can kidney beans"),
        ]
        // Instructions are handed in out of step order on purpose to pin
        // down that the formatter sorts by `step` rather than trusting
        // array order.
        let instructions = [
            RecipeInstruction(id: UUID(), step: 2, text: "Add beans and simmer."),
            RecipeInstruction(id: UUID(), step: 1, text: "Brown the beef."),
        ]
        let recipe = Recipe(
            id: 1,
            slug: "chili",
            title: "Dutch Oven Chili",
            excerpt: "Tasty.",
            canonicalURL: try #require(URL(string: "https://www.dutchovendaddy.com/r/1/")),
            publishedAt: Date(timeIntervalSince1970: 0),
            ingredients: ingredients,
            instructions: instructions
        )

        let expected = """
            Dutch Oven Chili

            Ingredients:
            - 1 lb ground beef
            - 1 can kidney beans

            Steps:
            1. Brown the beef.
            2. Add beans and simmer.

            https://www.dutchovendaddy.com/r/1/
            """

        #expect(RecipeShareTextFormatter.format(recipe: recipe) == expected)
    }

    @Test func omitsIngredientsSectionWhenEmpty() throws {
        let recipe = RecipeDetailTestFixtures.makeRecipe(id: 7, withDetail: true, ingredients: [])

        let expected = """
            Recipe 7

            Steps:
            1. Stir.

            https://www.dutchovendaddy.com/r/7/
            """

        #expect(RecipeShareTextFormatter.format(recipe: recipe) == expected)
    }

    @Test func omitsStepsSectionWhenEmpty() throws {
        let recipe = RecipeDetailTestFixtures.makeRecipe(
            id: 9,
            withDetail: false,
            ingredients: [RecipeIngredient(text: "salt")]
        )

        let expected = """
            Recipe 9

            Ingredients:
            - salt

            https://www.dutchovendaddy.com/r/9/
            """

        #expect(RecipeShareTextFormatter.format(recipe: recipe) == expected)
    }
}
