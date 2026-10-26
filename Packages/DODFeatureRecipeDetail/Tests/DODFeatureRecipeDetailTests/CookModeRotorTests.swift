import XCTest

@testable import DODFeatureRecipeDetail

final class CookModeRotorTests: XCTestCase {

    func test_allItemsAvailableWhenEverythingPresent() {
        // Given
        let result = CookModeRotorItem.available(hasNextStep: true, hasActiveTimer: true, hasStepIngredients: true)

        // Then
        XCTAssertEqual(result, CookModeRotorItem.allCases)
    }

    func test_lastStepNoTimerNoIngredientsKeepsCurrentAndExit() {
        // Given
        let result = CookModeRotorItem.available(hasNextStep: false, hasActiveTimer: false, hasStepIngredients: false)

        // Then
        XCTAssertEqual(result, [.currentStep, .exit])
    }

    func test_orderIsStable() {
        // Given
        let result = CookModeRotorItem.available(hasNextStep: true, hasActiveTimer: true, hasStepIngredients: true)

        // Then
        XCTAssertEqual(result, [.currentStep, .nextStep, .stepIngredients, .activeTimer, .exit])
    }

    func test_titlesAreNonEmptyAndUnique() {
        // Given
        let titles = CookModeRotorItem.allCases.map { $0.title }

        // Then
        XCTAssertFalse(titles.contains { $0.isEmpty })
        XCTAssertEqual(Set(titles).count, titles.count)
    }
}
