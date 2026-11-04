import Foundation
import Testing

@testable import DODSupport

@Suite("CampTrip")
struct CampTripTests {

    private func meal(_ day: Int, _ title: String) -> CampMeal {
        CampMeal(day: day, recipeTitle: title, ovenTempF: 350, task: .bake)
    }

    @Test func sequencedMealsSortsByDayAndKeepsInsertionOrderWithinADay() {
        let trip = CampTrip(
            name: "Lake",
            nights: 3,
            meals: [meal(1, "C"), meal(0, "A"), meal(1, "D"), meal(0, "B")]
        )
        #expect(trip.sequencedMeals.map(\.recipeTitle) == ["A", "B", "C", "D"])
    }

    @Test func tripRoundTripsThroughJSON() throws {
        let trip = CampTrip(
            name: "Lake",
            nights: 2,
            meals: [
                CampMeal(
                    day: 0,
                    recipeTitle: "Chili",
                    ovenTempF: 325,
                    ovenDiameterInches: 14,
                    task: .simmer,
                    ingredients: ["2 cans beans"]
                )
            ]
        )
        let data = try JSONEncoder().encode(trip)
        let decoded = try JSONDecoder().decode(CampTrip.self, from: data)
        #expect(decoded == trip)
    }

    @Test func cookTaskMapsAllFourCases() {
        #expect(CampMealTask.bake.cookTask == .bake)
        #expect(CampMealTask.roast.cookTask == .roast)
        #expect(CampMealTask.simmer.cookTask == .simmer)
        #expect(CampMealTask.fry.cookTask == .fry)
        #expect(CampMealTask.allCases.count == 4)
    }
}
