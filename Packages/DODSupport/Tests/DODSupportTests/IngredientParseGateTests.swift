import Testing

@testable import DODSupport

@Suite struct IngredientParseGateTests {

    @Test func modelQuantityMismatchWithHeuristicQuantity() {
        // Case (a): "2 cups flour" + model qty 4 → quantity stays 2
        let text = "2 cups flour"
        let model = IngredientParse(
            quantity: 4,
            unit: "cups",
            item: "flour",
            prep: nil
        )
        let result = IngredientParseGate.resolve(text: text, model: model)
        #expect(result.quantity == 2)
        #expect(result.name == "flour")
    }

    @Test func modelQuantityMatchesHeuristicQuantity() {
        // Case (b): "2 cups flour" + model qty 2 item "flour" → candidate used
        let text = "2 cups flour"
        let model = IngredientParse(
            quantity: 2,
            unit: "cups",
            item: "flour",
            prep: nil
        )
        let result = IngredientParseGate.resolve(text: text, model: model)
        #expect(result.quantity == 2)
        #expect(result.name == "flour")
    }

    @Test func heuristicQuantityNoneModelHasQuantity() {
        // Case (c): "salt to taste" + model qty 1 → quantity nil (heuristic, verbatim)
        let text = "salt to taste"
        let model = IngredientParse(
            quantity: 1,
            unit: nil,
            item: "salt",
            prep: nil
        )
        let result = IngredientParseGate.resolve(text: text, model: model)
        #expect(result.quantity == nil)
        #expect(result.name == "salt")
    }

    @Test func heuristicQuantityNoneModelHasQuantityAndPrep() {
        // Case (d): "salt to taste" + model qty nil item "salt", prep "to taste" → name "salt"
        let text = "salt to taste"
        let model = IngredientParse(
            quantity: nil,
            unit: nil,
            item: "salt",
            prep: "to taste"
        )
        let result = IngredientParseGate.resolve(text: text, model: model)
        #expect(result.quantity == nil)
        #expect(result.name == "salt")
    }

    @Test func modelNilReturnsHeuristic() {
        // Case (e): model: nil → equals heuristic
        let text = "2 cups flour"
        let result = IngredientParseGate.resolve(text: text, model: nil)
        #expect(result.quantity == 2)
        #expect(result.name == "flour")
    }
}
