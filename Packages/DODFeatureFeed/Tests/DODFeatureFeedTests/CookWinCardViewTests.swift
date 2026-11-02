import SwiftUI
import XCTest

@testable import DODFeatureFeed
@testable import DODSupport

@MainActor
final class CookWinCardViewTests: XCTestCase {
    func cardHasFixedSize() {
        XCTAssertEqual(CookWinCardView.size, CGSize(width: 360, height: 450))
    }

    func buildsWithoutPhoto() {
        let entry = CookLogEntry(
            id: UUID(),
            recipeID: 123,
            recipeTitle: "Test Dish",
            cookedAt: Date(),
            note: "Test Headline",
            personalRating: nil,
            photoLocalID: nil
        )

        let view = CookWinCardView(content: CookWinCardContent(entry: entry), photo: nil)
        _ = view.body
    }
}
