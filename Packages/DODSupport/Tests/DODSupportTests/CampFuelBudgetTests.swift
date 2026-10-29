import XCTest

@testable import DODSupport

final class CampFuelBudgetTests: XCTestCase {

    func testEmptyTrip() {
        let trip = CampTrip(name: "Test Trip", nights: 0, meals: [])
        let budget = CampFuelBudget.budget(for: trip)

        XCTAssertEqual(budget.totalBriquettes, 0)
        XCTAssertEqual(budget.perMeal.count, 0)
    }

    func testThree12InchMealsAt350F() {
        let meal1 = CampMeal(
            id: UUID(),
            day: 1,
            recipeTitle: "Test Recipe 1",
            ovenTempF: 350,
            ovenDiameterInches: 12,
            task: .bake
        )

        let meal2 = CampMeal(
            id: UUID(),
            day: 2,
            recipeTitle: "Test Recipe 2",
            ovenTempF: 350,
            ovenDiameterInches: 12,
            task: .bake
        )

        let meal3 = CampMeal(
            id: UUID(),
            day: 3,
            recipeTitle: "Test Recipe 3",
            ovenTempF: 350,
            ovenDiameterInches: 12,
            task: .bake
        )

        let trip = CampTrip(name: "Test Trip", nights: 2, meals: [meal1, meal2, meal3])
        let budget = CampFuelBudget.budget(for: trip)

        XCTAssertEqual(budget.totalBriquettes, 72)  // 24 briquettes each
        XCTAssertEqual(budget.perMeal.count, 3)
        XCTAssertEqual(budget.perMeal[0].briquettes, 24)
        XCTAssertEqual(budget.perMeal[1].briquettes, 24)
        XCTAssertEqual(budget.perMeal[2].briquettes, 24)
    }

    func test12InchMealAt400F() {
        let meal = CampMeal(
            id: UUID(),
            day: 1,
            recipeTitle: "Test Recipe",
            ovenTempF: 400,
            ovenDiameterInches: 12,
            task: .bake
        )

        let trip = CampTrip(name: "Test Trip", nights: 1, meals: [meal])
        let budget = CampFuelBudget.budget(for: trip)

        XCTAssertEqual(budget.totalBriquettes, 28)  // 28 briquettes for 400°F
    }

    func testMealsOutOfOrder() {
        let meal1 = CampMeal(
            id: UUID(),
            day: 3,
            recipeTitle: "Test Recipe 1",
            ovenTempF: 350,
            ovenDiameterInches: 12,
            task: .bake
        )

        let meal2 = CampMeal(
            id: UUID(),
            day: 1,
            recipeTitle: "Test Recipe 2",
            ovenTempF: 350,
            ovenDiameterInches: 12,
            task: .bake
        )

        let meal3 = CampMeal(
            id: UUID(),
            day: 2,
            recipeTitle: "Test Recipe 3",
            ovenTempF: 350,
            ovenDiameterInches: 12,
            task: .bake
        )

        let trip = CampTrip(name: "Test Trip", nights: 2, meals: [meal1, meal2, meal3])
        let budget = CampFuelBudget.budget(for: trip)

        XCTAssertEqual(budget.perMeal.count, 3)
        XCTAssertEqual(budget.perMeal[0].day, 1)  // Should be in day order
        XCTAssertEqual(budget.perMeal[1].day, 2)
        XCTAssertEqual(budget.perMeal[2].day, 3)
    }
}
