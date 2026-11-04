import XCTest

@testable import DODSupport

final class CampFuelLedgerTests: XCTestCase {

    func testInitWithPackedBriquettes() {
        let ledger = CampFuelLedger(packedBriquettes: 100)
        XCTAssertEqual(ledger.packedBriquettes, 100)
        XCTAssertEqual(ledger.remaining, 100)
        XCTAssertEqual(ledger.totalUsed, 0)
    }

    func testInitWithNegativePackedBriquettes() {
        let ledger = CampFuelLedger(packedBriquettes: -10)
        XCTAssertEqual(ledger.packedBriquettes, 0)
        XCTAssertEqual(ledger.remaining, 0)
        XCTAssertEqual(ledger.totalUsed, 0)
    }

    func testInitWithBudget() {
        let trip = CampTrip(name: "Test Trip", nights: 2, meals: [])
        let budget = CampFuelBudget.budget(for: trip)
        let ledger = CampFuelLedger(budget: budget)
        XCTAssertEqual(ledger.packedBriquettes, budget.totalBriquettes)
    }

    func testRecordUsed() {
        let mealID = UUID()
        var ledger = CampFuelLedger(packedBriquettes: 100)

        ledger.recordUsed(20, for: mealID)
        XCTAssertEqual(ledger.remaining, 80)
        XCTAssertEqual(ledger.totalUsed, 20)

        // Re-record the same meal - should replace
        ledger.recordUsed(30, for: mealID)
        XCTAssertEqual(ledger.remaining, 70)
        XCTAssertEqual(ledger.totalUsed, 30)
    }

    func testRecordUsedNegativeInput() {
        let mealID = UUID()
        var ledger = CampFuelLedger(packedBriquettes: 100)

        ledger.recordUsed(-10, for: mealID)
        XCTAssertEqual(ledger.remaining, 100)
        XCTAssertEqual(ledger.totalUsed, 0)
    }

    func testRemaining() {
        let mealID1 = UUID()
        let mealID2 = UUID()
        var ledger = CampFuelLedger(packedBriquettes: 50)

        ledger.recordUsed(20, for: mealID1)
        XCTAssertEqual(ledger.remaining, 30)

        ledger.recordUsed(15, for: mealID2)
        XCTAssertEqual(ledger.remaining, 15)
    }

    func testIsShort() {
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

        let trip = CampTrip(name: "Test Trip", nights: 1, meals: [meal1, meal2])
        let budget = CampFuelBudget.budget(for: trip)

        // Test when not short (packed equals budget)
        var ledger = CampFuelLedger(budget: budget)
        XCTAssertFalse(ledger.isShort(for: budget))

        // Test when short (10 fewer packed than needed)
        ledger = CampFuelLedger(packedBriquettes: budget.totalBriquettes - 10)
        XCTAssertTrue(ledger.isShort(for: budget))

        // Record one meal as used, should still be short since only one of two meals is cooked
        let mealID = meal1.id
        ledger.recordUsed(24, for: mealID)
        XCTAssertTrue(ledger.isShort(for: budget))  // Still short because second meal not yet cooked

        // Record the other meal as used, should no longer be short
        let mealID2 = meal2.id
        ledger.recordUsed(24, for: mealID2)
        XCTAssertFalse(ledger.isShort(for: budget))  // No longer short since all meals are cooked
    }
}
