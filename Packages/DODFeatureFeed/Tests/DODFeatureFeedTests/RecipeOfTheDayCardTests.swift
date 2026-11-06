import DODDomain
import Foundation
import Testing

@testable import DODFeatureFeed

@Suite("RecipeOfTheDayCard (DUT-117)")
struct RecipeOfTheDayCardTests {

    private func item(excerpt: String) -> RecipeListItem {
        RecipeListItem(
            id: 1,
            title: "Skillet Corn",
            excerpt: excerpt,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    @Test func usesFirstSentence() {
        let hook = RecipeOfTheDayCard.hook(for: item(excerpt: "Smoky and rich. Serves four."))
        #expect(hook == "Smoky and rich")
    }

    @Test func emptyExcerptFallsBack() {
        let hook = RecipeOfTheDayCard.hook(for: item(excerpt: ""))
        #expect(hook == RecipeOfTheDayCard.fallbackHook)
    }

    @Test func overlongFirstSentenceFallsBack() {
        let hook = RecipeOfTheDayCard.hook(for: item(excerpt: String(repeating: "a", count: 100)))
        #expect(hook == RecipeOfTheDayCard.fallbackHook)
    }
}
