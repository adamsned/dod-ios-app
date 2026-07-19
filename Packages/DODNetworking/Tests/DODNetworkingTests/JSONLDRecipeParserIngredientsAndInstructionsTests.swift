import DODDomain
import Foundation
import Testing

@testable import DODNetworking

@Suite("JSONLDRecipeParser.ingredientsAndInstructions (direct unit tests)") struct IngredientsAndInstructionsTests {

    /// Shared WPRM HTML fixture (from existing `recoversBothListsFromStandardWPRMCard` test).
    /// Parses to:
    ///   - ingredients: ["3 lbs lean ground beef", "1 onion diced"]
    ///   - instructions: ["Heat the Dutch oven over medium-high heat", "Crumble in the ground beef; stir."]
    private static let standardWPRMCard = """
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
        """

    /// Partial fallback case 1: Only ingredients present in JSON-LD (instructions missing).
    /// Instructions should be filled from WPRM card, ingredients pass through verbatim.
    @Test func fillsMissingInstructionsFromWPRMCardWhenIngredientsPresent() {
        let jsonLD: [String: Any] = [
            "recipeIngredient": ["2 cups sugar", "1 tsp vanilla"]
        ]

        let (ingredients, instructions) = JSONLDRecipeParser.ingredientsAndInstructions(
            jsonLD: jsonLD,
            html: Self.standardWPRMCard
        )

        // Ingredients from JSON-LD, unchanged
        #expect(ingredients.map(\.text) == ["2 cups sugar", "1 tsp vanilla"])

        // Instructions filled from WPRM card
        #expect(
            instructions.map(\.text) == [
                "Heat the Dutch oven over medium-high heat",
                "Crumble in the ground beef; stir.",
            ]
        )
        #expect(instructions.map(\.step) == [1, 2])
    }

    /// Partial fallback case 2: Only instructions present in JSON-LD (ingredients missing).
    /// Ingredients should be filled from WPRM card, instructions pass through verbatim.
    @Test func fillsMissingIngredientsFromWPRMCardWhenInstructionsPresent() {
        let jsonLD: [String: Any] = [
            "recipeInstructions": [
                ["@type": "HowToStep", "text": "Preheat the oven."],
                ["@type": "HowToStep", "text": "Mix ingredients."],
            ]
        ]

        let (ingredients, instructions) = JSONLDRecipeParser.ingredientsAndInstructions(
            jsonLD: jsonLD,
            html: Self.standardWPRMCard
        )

        // Ingredients filled from WPRM card
        #expect(ingredients.map(\.text) == ["3 lbs lean ground beef", "1 onion diced"])

        // Instructions from JSON-LD, unchanged
        #expect(
            instructions.map(\.text) == [
                "Preheat the oven.",
                "Mix ingredients.",
            ]
        )
        #expect(instructions.map(\.step) == [1, 2])
    }

    /// Regression test: fast-path when both are present in JSON-LD.
    /// WPRM card is not consulted even if it has completely different content.
    /// This validates the efficiency gate: early return skips WPRM parsing for complete JSON-LD.
    @Test func skipsWPRMCardWhenBothIngredientsAndInstructionsPresent() {
        let wprmWithDifferentContent = """
            <div class="wprm-recipe-container">
            <ul class="wprm-recipe-ingredients">
            <li class="wprm-recipe-ingredient"><span class="wprm-recipe-ingredient-name">WPRM INGREDIENT</span></li>
            </ul>
            <ul class="wprm-recipe-instructions">
            <li class="wprm-recipe-instruction"><div class="wprm-recipe-instruction-text"><span style="display: block;">WPRM INSTRUCTION</span></div></li>
            </ul>
            </div>
            """

        let jsonLD: [String: Any] = [
            "recipeIngredient": ["2 cans corn", "2 tbsp butter"],
            "recipeInstructions": [
                ["@type": "HowToStep", "text": "Melt butter."],
                ["@type": "HowToStep", "text": "Add corn."],
            ],
        ]

        let (ingredients, instructions) = JSONLDRecipeParser.ingredientsAndInstructions(
            jsonLD: jsonLD,
            html: wprmWithDifferentContent
        )

        // Both are from JSON-LD, WPRM content is completely ignored
        #expect(ingredients.map(\.text) == ["2 cans corn", "2 tbsp butter"])
        #expect(instructions.map(\.text) == ["Melt butter.", "Add corn."])
        #expect(!ingredients.contains { $0.text.contains("WPRM") })
        #expect(!instructions.contains { $0.text.contains("WPRM") })
    }

    /// Neither ingredients nor instructions present in JSON-LD.
    /// Both should be filled from the WPRM card.
    @Test func fillsBothFromWPRMCardWhenJSONLDIsEmpty() {
        let jsonLD: [String: Any] = [:]

        let (ingredients, instructions) = JSONLDRecipeParser.ingredientsAndInstructions(
            jsonLD: jsonLD,
            html: Self.standardWPRMCard
        )

        // Both filled from WPRM card
        #expect(ingredients.map(\.text) == ["3 lbs lean ground beef", "1 onion diced"])
        #expect(
            instructions.map(\.text) == [
                "Heat the Dutch oven over medium-high heat",
                "Crumble in the ground beef; stir.",
            ]
        )
        #expect(instructions.map(\.step) == [1, 2])
    }
}
