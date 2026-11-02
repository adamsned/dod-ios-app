import Testing

@Suite struct AskRecipeToolboxTests {
    private let toolbox = AskRecipeToolbox(
        title: "Test Recipe",
        servings: 4,
        scaledIngredients: [
            "2 cups flour",
            "1 cup sugar",
            "3 eggs",
            "1 cup butter",
        ],
        steps: [
            "Preheat oven to 350°F.",
            "Mix ingredients together.",
            "Bake for 30 minutes.",
            "Cool before serving.",
        ]
    )

    @Test func ingredientsMatchingIsCaseInsensitive() {
        let result = toolbox.ingredients(matching: "FLOUR")
        #expect(result == ["2 cups flour"])
    }

    @Test func emptyKeywordReturnsAllCapped() {
        let result = toolbox.ingredients(matching: "")
        #expect(result == toolbox.scaledIngredients)
    }

    @Test func stepNumberOutOfRangeIsNil() {
        let result = toolbox.step(number: 10)
        #expect(result == nil)
    }

    @Test func stepsMatchingNumbersFromOne() {
        let result = toolbox.steps(matching: "bake")
        #expect(result == ["3. Bake for 30 minutes."])
    }
}
