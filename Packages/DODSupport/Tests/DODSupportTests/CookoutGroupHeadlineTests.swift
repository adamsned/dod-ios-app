import XCTest

@testable import DODSupport

final class CookoutGroupHeadlineTests: XCTestCase {
    func testHeadline() throws {
        let calendar = Calendar(identifier: .gregorian)
        let locale = Locale(identifier: "en_US")
        let testDate = Date(timeIntervalSince1970: 1_767_523_200)  // 2026-01-04 is a Sunday

        // Test with 4 entries and fed: 10
        let group1 = CookoutGroup(
            day: testDate,
            entries: Array(
                repeating: .init(
                    id: UUID(),
                    recipeID: 123,
                    recipeTitle: "Test Dish",
                    cookedAt: testDate
                ),
                count: 4
            )
        )

        XCTAssertEqual(
            group1.headline(fed: 10, calendar: calendar, locale: locale),
            "Sunday cookout — 4 dishes, fed 10"
        )

        // Test with 2 entries and no fed
        let group2 = CookoutGroup(
            day: testDate,
            entries: Array(
                repeating: .init(
                    id: UUID(),
                    recipeID: 123,
                    recipeTitle: "Test Dish",
                    cookedAt: testDate
                ),
                count: 2
            )
        )

        XCTAssertEqual(
            group2.headline(calendar: calendar, locale: locale),
            "Sunday cookout — 2 dishes"
        )

        // Test with fed: 0 (should be ignored)
        XCTAssertEqual(
            group1.headline(fed: 0, calendar: calendar, locale: locale),
            "Sunday cookout — 4 dishes"
        )
    }
}
