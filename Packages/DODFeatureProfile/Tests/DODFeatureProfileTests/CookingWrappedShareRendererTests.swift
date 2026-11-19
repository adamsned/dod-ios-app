import SwiftUI
import XCTest

@testable import DODFeatureProfile

final class CookingWrappedShareRendererTests: XCTestCase {
    @MainActor
    func testEmptyCardsRenderNothing() {
        XCTAssertNil(CookingWrappedShareRenderer.render(cards: []))
    }

    @MainActor
    func testCardsRenderAnImageOfExpectedWidth() {
        #if os(iOS)
        let card = CookingWrappedCard(
            id: "t",
            emoji: "🍽️",
            headline: "5 meals",
            detail: "Thanks"
        )
        let image = CookingWrappedShareRenderer.render(cards: [card])
        XCTAssertNotNil(image)
        XCTAssertEqual(image?.width, 780)  // 390 × scale 2
        #endif
    }
}
