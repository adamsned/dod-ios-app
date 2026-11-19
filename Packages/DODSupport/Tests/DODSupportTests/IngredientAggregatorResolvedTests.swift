import DODDomain
import Foundation
import Testing

@testable import DODSupport

/// DUT-1020: pre-resolved parses feed `IngredientAggregator` as the merge key.
@Suite("IngredientAggregator resolved parses")
struct IngredientAggregatorResolvedTests {

    @Test func resolvedParseOverridesHeuristicForMerging() throws {
        let firstIngredient = RecipeIngredient(text: "2 cups flour", index: 0)
        let secondIngredient = RecipeIngredient(text: "flour, 1 cup", index: 1)  // heuristic: unparseable
        let fix = try #require(
            IngredientParse(quantity: 1, unit: "cup", item: "flour", prep: nil)
                .asParsedLine(originalText: secondIngredient.text)
        )
        let result = IngredientAggregator.aggregate(
            [firstIngredient, secondIngredient],
            resolved: [secondIngredient.id: fix]
        )
        #expect(result.count == 1)
        #expect(result[0].quantity == 3)
        #expect(result[0].sourceCount == 2)
    }
}
