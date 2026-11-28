import XCTest

@testable import DODDesignSystem

final class DietaryBadgeTests: XCTestCase {

    func testDietaryBadgeText() {
        // Test .fitsDiet text
        let fitsDietBadge = DietaryBadge(kind: .fitsDiet)
        XCTAssertEqual(fitsDietBadge.text, "Fits your diet")

        // Test .allergenWarning text
        let allergenBadge = DietaryBadge(kind: .allergenWarning("Contains Nuts"))
        XCTAssertEqual(allergenBadge.text, "Contains Nuts")

        // Test .unverified text
        let unverifiedBadge = DietaryBadge(kind: .unverified)
        XCTAssertEqual(unverifiedBadge.text, "Allergens unverified")
    }
}
