import DODSupport
import Foundation
import Testing

@testable import DODFeatureSaved

@Suite struct CampTripPackListTests {

    private static func meal(day: Int, title: String, ingredients: [String]) -> CampMeal {
        CampMeal(
            day: day,
            recipeTitle: title,
            ovenTempF: 350,
            ovenDiameterInches: 12,
            task: .bake,
            ingredients: ingredients
        )
    }

    private static func twoMealTrip() -> CampTrip {
        CampTrip(
            name: "Lake Weekend",
            nights: 2,
            meals: [
                meal(day: 1, title: "Cobbler", ingredients: ["3 peaches", "1 cup flour", "1 stick butter"]),
                meal(day: 0, title: "Chili", ingredients: ["1 lb ground beef", "2 cups beans"]),
            ]
        )
    }

    private static func freshStore() -> ShoppingListStore {
        let suite = "dut1878.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        return ShoppingListStore(defaults: defaults)
    }

    @Test func twoMealsGiveIngredientRowsThenFuelRowLast() {
        let rows = CampTripPackList.rows(for: Self.twoMealTrip())
        #expect(rows.count == 6)
        #expect(rows[0].recipeTitle == "Day 1 · Chili")
        #expect(rows[2].recipeTitle == "Day 2 · Cobbler")
        #expect(rows[5].ingredientText == "48 charcoal briquettes")
        #expect(rows[5].recipeTitle == "Lake Weekend")
        #expect(rows[5].aisle == .other)
    }

    @Test func emptyTripGivesNoRows() {
        #expect(CampTripPackList.rows(for: CampTrip(name: "Empty", nights: 0)).isEmpty)
    }

    @Test func mealWithoutIngredientsStillAddsFuelRow() {
        let trip = CampTrip(name: "Bare", nights: 1, meals: [Self.meal(day: 0, title: "Toast", ingredients: [])])
        let rows = CampTripPackList.rows(for: trip)
        #expect(rows.count == 1)
        #expect(rows[0].ingredientText == "24 charcoal briquettes")
    }

    @Test func appendingRowsToStoreReturnsRowCount() {
        let rows = CampTripPackList.rows(for: Self.twoMealTrip())
        let store = Self.freshStore()
        #expect(store.append(rows: rows) == rows.count)
    }
}
