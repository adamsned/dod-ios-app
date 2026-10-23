import XCTest

@testable import DODFeatureFeed

final class CookoutRecapCardTests: XCTestCase {

    func testVisibleDishLinesPassesThroughShortList() {
        let input = ["Dish 1", "Dish 2", "Dish 3"]
        let expected = ["Dish 1", "Dish 2", "Dish 3"]
        XCTAssertEqual(CookoutRecapCard.visibleDishLines(input), expected)
    }

    func testVisibleDishLinesTruncatesWithMoreTail() {
        let input = Array(repeating: "Dish", count: 8)
        let expected = ["Dish", "Dish", "Dish", "Dish", "Dish", "Dish", "+2 more"]
        XCTAssertEqual(CookoutRecapCard.visibleDishLines(input), expected)
    }
}
