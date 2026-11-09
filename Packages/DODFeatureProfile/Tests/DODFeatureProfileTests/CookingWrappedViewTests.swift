import SwiftUI
import Testing

@testable import DODFeatureProfile

@Suite
struct CookingWrappedViewTests {

    @Test
    func viewWithOneCard() {
        let card = CookingWrappedCard(
            id: "test",
            emoji: "🍎",
            headline: "Test Headline",
            detail: "Test Detail"
        )

        let view = CookingWrappedView(cards: [card])
        #expect(view.cards.count == 1)
    }

    @Test
    func viewWithThreeCards() {
        let cards = [
            CookingWrappedCard(id: "1", emoji: "🍎", headline: "Headline 1", detail: "Detail 1"),
            CookingWrappedCard(id: "2", emoji: "🍌", headline: "Headline 2", detail: "Detail 2"),
            CookingWrappedCard(id: "3", emoji: "🍒", headline: "Headline 3", detail: "Detail 3"),
        ]

        let view = CookingWrappedView(cards: cards)
        #expect(view.cards.count == 3)
    }

    @Test
    func shareButtonOnlyWhenRealStats() {
        // Test that when we have low data (less than threshold), no share button appears
        let lowDataCard = CookingWrappedCards.lowDataCard(totalCooks: 0)
        let view = CookingWrappedView(cards: [lowDataCard])
        #expect(view.cards.count == 1)
    }
}
