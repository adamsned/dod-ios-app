import DODDomain
import Testing

@testable import DODIntelligence

struct RecipeCardTextParserTests {
    @Test
    func parsesRecipeWithTitleIngredientsAndDirections() {
        let input =
            "Grandma's Gumbo\nIngredients:\n- 1 cup flour\n- 1 cup oil\nDirections\n1. Make a roux.\n2) Add the trinity."

        let result = RecipeCardTextParser.parse(input)

        #expect(result != nil)
        #expect(result?.title == "Grandma's Gumbo")
        #expect(result?.ingredients.count == 2)
        #expect(result?.ingredients[0].text == "1 cup flour")
        #expect(result?.ingredients[1].text == "1 cup oil")
        #expect(result?.instructions.count == 2)
        #expect(result?.instructions[0].step == 1)
        #expect(result?.instructions[0].text == "Make a roux.")
        #expect(result?.instructions[1].step == 2)
        #expect(result?.instructions[1].text == "Add the trinity.")
    }

    @Test
    func returnsNilForJustTitle() {
        let input = "Just a title"

        let result = RecipeCardTextParser.parse(input)

        #expect(result == nil)
    }

    @Test
    func parsesIngredientsOnly() {
        let input = "Ingredients\nsalt"

        let result = RecipeCardTextParser.parse(input)

        #expect(result != nil)
        #expect(result?.title == "Family Recipe")
        #expect(result?.ingredients.count == 1)
        #expect(result?.ingredients[0].text == "salt")
    }
}
