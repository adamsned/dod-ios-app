import Testing

@testable import DODSupport

@Suite struct WPRMRecipeCardParserGroupTests {
    @Test func cardExposesLabelledIngredientGroups() {
        let html = """
            <div class="wprm-recipe-container">
            <div class="wprm-recipe-ingredients-container">
            <div class="wprm-recipe-ingredient-group"><h4 class="wprm-recipe-ingredient-group-name">For the Crust:</h4>
            <ul class="wprm-recipe-ingredients">
            <li class="wprm-recipe-ingredient"><span class="wprm-recipe-ingredient-amount">1</span> <span class="wprm-recipe-ingredient-unit">cup</span> <span class="wprm-recipe-ingredient-name">flour</span></li>
            <li class="wprm-recipe-ingredient"><span class="wprm-recipe-ingredient-amount">1</span> <span class="wprm-recipe-ingredient-unit">tsp</span> <span class="wprm-recipe-ingredient-name">salt</span></li>
            </ul></div>
            <div class="wprm-recipe-ingredient-group"><h4 class="wprm-recipe-ingredient-group-name">For the Filling:</h4>
            <ul class="wprm-recipe-ingredients">
            <li class="wprm-recipe-ingredient"><span class="wprm-recipe-ingredient-amount">2</span> <span class="wprm-recipe-ingredient-unit">cups</span> <span class="wprm-recipe-ingredient-name">milk</span></li>
            </ul></div>
            </div>
            </div>
            """
        let card = WPRMRecipeCardParser.parse(html: html)
        #expect(card.ingredientGroups.map(\.count) == [2, 1])
        #expect(card.ingredientGroups.map(\.label) == ["For the Crust:", "For the Filling:"])
    }

    @Test func bareListCardHasNoIngredientGroups() {
        let html = """
            <div class="wprm-recipe-container"><ul class="wprm-recipe-ingredients">
            <li class="wprm-recipe-ingredient"><span class="wprm-recipe-ingredient-name">salt</span></li>
            </ul></div>
            """
        #expect(WPRMRecipeCardParser.parse(html: html).ingredientGroups.isEmpty)
    }
}
