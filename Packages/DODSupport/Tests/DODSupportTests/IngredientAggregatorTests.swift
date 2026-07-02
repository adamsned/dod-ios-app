import DODDomain
import Foundation
import Testing

@testable import DODSupport

/// Golden L1 coverage for ``IngredientAggregator``.
///
/// Spec trace: US-39 / AC-39.4 (aisle grouping), AC-39.7 (rolled-up share
/// path), AC-39.12 (pure on-device). CL-70 (same-unit summation), CL-77 (the
/// v1 UI keeps per-recipe rows; this is a reusable capability), CL-80 (the
/// logic-core split). Constitution §6 L1 mandate.
@Suite("IngredientAggregator")
struct IngredientAggregatorTests {

    private typealias Aisle = IngredientAisleClassifier.Aisle

    /// Convenience: build `[RecipeIngredient]` from raw text lines.
    private func ingredients(_ lines: String...) -> [RecipeIngredient] {
        lines.map { RecipeIngredient(text: $0) }
    }

    // MARK: - Empty + single

    @Test func emptyInputProducesEmptyOutput() {
        #expect(IngredientAggregator.aggregate([]).isEmpty)
    }

    @Test func singleItemPassesThrough() {
        let result = IngredientAggregator.aggregate(ingredients("2 cups all-purpose flour"))
        #expect(result.count == 1)
        #expect(result[0].displayText == "2 cups all-purpose flour")
        #expect(result[0].aisle == .pantry)
        #expect(result[0].sourceCount == 1)
        #expect(result[0].quantity == 2)
        #expect(result[0].unit == "cup")
    }

    // MARK: - Same-unit merge

    @Test func sameUnitSameNameMergesAndSums() {
        let result = IngredientAggregator.aggregate(
            ingredients("2 cups flour", "1 cup flour")
        )
        #expect(result.count == 1)
        #expect(result[0].quantity == 3)
        #expect(result[0].displayText == "3 cups flour")
        #expect(result[0].sourceCount == 2)
    }

    /// DUT-383: the merge is case-insensitive (the doc promises it), so
    /// `"Flour"` and `"flour"` roll into one summed row. The display keeps the
    /// first-seen casing.
    @Test func differentlyCasedNamesMergeCaseInsensitively() {
        let result = IngredientAggregator.aggregate(
            ingredients("2 cups Flour", "1 cup flour")
        )
        #expect(result.count == 1)
        #expect(result[0].quantity == 3)
        #expect(result[0].sourceCount == 2)
        #expect(result[0].displayText == "3 cups Flour")
    }

    @Test func unitAbbreviationAndSpelledOutMerge() {
        // "tbsp" and "tablespoons" normalize to the same canonical unit.
        let result = IngredientAggregator.aggregate(
            ingredients("1 tbsp olive oil", "2 tablespoons olive oil")
        )
        #expect(result.count == 1)
        #expect(result[0].quantity == 3)
        #expect(result[0].unit == "tablespoon")
        #expect(result[0].displayText == "3 tablespoons olive oil")
        #expect(result[0].aisle == .pantry)
    }

    @Test func pluralAndSingularCupMerge() {
        let result = IngredientAggregator.aggregate(
            ingredients("1 cup whole milk", "1 cups whole milk")
        )
        #expect(result.count == 1)
        #expect(result[0].quantity == 2)
        #expect(result[0].displayText == "2 cups whole milk")
    }

    @Test func threeRecipesOfSameIngredientRollUp() {
        let result = IngredientAggregator.aggregate(
            ingredients("2 cups diced onion", "2 cups diced onion", "2 cups diced onion")
        )
        #expect(result.count == 1)
        #expect(result[0].quantity == 6)
        #expect(result[0].sourceCount == 3)
        #expect(result[0].displayText == "6 cups diced onion")
        #expect(result[0].aisle == .produce)
    }

    // MARK: - Fraction math (reuses FractionRenderer)

    @Test func halfPlusQuarterCupIsThreeQuarters() {
        let result = IngredientAggregator.aggregate(
            ingredients("½ cup sugar", "¼ cup sugar")
        )
        #expect(result.count == 1)
        #expect(result[0].displayText == "¾ cup sugar")
    }

    @Test func halfPlusHalfCupIsOne() {
        let result = IngredientAggregator.aggregate(
            ingredients("1/2 cup sour cream", "1/2 cup sour cream")
        )
        #expect(result.count == 1)
        #expect(result[0].displayText == "1 cup sour cream")
        #expect(result[0].aisle == .dairy)
    }

    @Test func mixedNumberPlusFractionNormalizes() {
        // 1 ½ + ½ = 2.
        let result = IngredientAggregator.aggregate(
            ingredients("1 1/2 cups broth", "1/2 cup broth")
        )
        #expect(result.count == 1)
        #expect(result[0].quantity == 2)
        #expect(result[0].displayText == "2 cups broth")
    }

    @Test func decimalQuantitiesSum() {
        let result = IngredientAggregator.aggregate(
            ingredients("1.5 cups rice", "1.5 cups rice")
        )
        #expect(result.count == 1)
        #expect(result[0].quantity == 3)
        #expect(result[0].displayText == "3 cups rice")
    }

    // MARK: - No-merge cases

    @Test func differentUnitsStaySeparate() {
        let result = IngredientAggregator.aggregate(
            ingredients("2 cups onion", "1 lb onion")
        )
        #expect(result.count == 2)
        // Both land in produce; both keep their own quantity.
        #expect(result.allSatisfy { $0.aisle == .produce })
        #expect(Set(result.map(\.unit)) == Set(["cup", "pound"]))
    }

    @Test func differentNamesStaySeparate() {
        let result = IngredientAggregator.aggregate(
            ingredients("1 cup yellow onion", "1 cup red onion")
        )
        #expect(result.count == 2)
    }

    @Test func unparseableLinesNeverMerge() {
        // No leading quantity → verbatim, never merged, even when identical.
        let result = IngredientAggregator.aggregate(
            ingredients("Salt and pepper to taste", "Salt and pepper to taste")
        )
        #expect(result.count == 2)
        #expect(result.allSatisfy { $0.displayText == "Salt and pepper to taste" })
        #expect(result.allSatisfy { $0.quantity == nil })
        #expect(result.allSatisfy { $0.unit == nil })
    }

    @Test func bareCountWithoutUnitStaysSeparate() {
        // "2 eggs" has a quantity but no *unit* — kept distinct per line so we
        // never guess that "2 eggs" + "3 eggs" is the same shopping entry.
        let result = IngredientAggregator.aggregate(
            ingredients("2 eggs", "3 eggs")
        )
        #expect(result.count == 2)
        #expect(result.allSatisfy { $0.aisle == .dairy })
    }

    // MARK: - Aisle grouping / ordering

    @Test func resultsAreGroupedByAisleInWalkOrder() {
        // Input deliberately out of aisle order; output must be produce →
        // meat → dairy → pantry → spices → other (Aisle.allCases order).
        let result = IngredientAggregator.aggregate(
            ingredients(
                "1 tsp paprika",  // spices
                "2 cups flour",  // pantry
                "1 onion",  // produce (no unit → still classified)
                "1 lb chicken breast"  // meat
            )
        )
        let aisles = result.map(\.aisle)
        let ranks = aisles.compactMap { Aisle.allCases.firstIndex(of: $0) }
        #expect(ranks == ranks.sorted())
        #expect(aisles.first == .produce)
        #expect(aisles.last == .spices)
    }

    @Test func mixedListMergesWithinAisleAndKeepsOthers() {
        let result = IngredientAggregator.aggregate(
            ingredients(
                "1 cup flour",
                "1 cup flour",  // merges with the first → "2 cups flour"
                "1 tsp salt",  // spices, distinct
                "Juice of 1 lemon"  // produce-ish; "lemon" keyword, no leading qty → verbatim
            )
        )
        // flour merged (1), salt (1), lemon line (1) = 3 items.
        #expect(result.count == 3)
        let flour = result.first { $0.name == "flour" }
        #expect(flour?.quantity == 2)
        #expect(flour?.sourceCount == 2)
    }
}
