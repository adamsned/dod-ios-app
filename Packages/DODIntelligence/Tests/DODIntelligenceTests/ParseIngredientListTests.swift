import XCTest

@testable import DODIntelligence

final class ParseIngredientListTests: XCTestCase {

    func testSplitsOnCommaSemicolonAndNewline() {
        let result = LiveDODIntelligenceService.parseIngredientList("Eggs, Milk;Butter\nCheese")
        XCTAssertEqual(result, ["eggs", "milk", "butter", "cheese"])
    }

    func testTrimsLowercasesAndDedupes() {
        let result = LiveDODIntelligenceService.parseIngredientList("  Eggs ,EGGS,, milk ")
        XCTAssertEqual(result, ["eggs", "milk"])
    }

    func testEmptyInputGivesEmptyList() {
        XCTAssertEqual(LiveDODIntelligenceService.parseIngredientList(""), [])
    }
}
