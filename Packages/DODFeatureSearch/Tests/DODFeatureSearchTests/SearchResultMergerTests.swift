import DODDomain
import Foundation
import Testing

@testable import DODFeatureSearch

@Suite("SearchResultMerger (US-12 / REG-12)") struct SearchResultMergerTests {

    @Test func restTitleHitsRankAboveExcerptHits() {
        let titleHit = item(1, title: "Garlic Bread", excerpt: "A classic")
        let excerptHit = item(2, title: "Crusty Loaf", excerpt: "Goes with garlic butter")
        let merged = SearchResultMerger.merge(
            query: "garlic",
            restResults: [excerptHit, titleHit],
            localIngredientResults: []
        )
        #expect(merged.map(\.id) == [1, 2], "Title match must rank above excerpt match")
    }

    @Test func localIngredientHitsRankBelowAllRestHits() {
        let restHit = item(1, title: "Garlic Bread", excerpt: "x")
        let localHit = item(2, title: "Pasta Bake", excerpt: "x")
        let merged = SearchResultMerger.merge(
            query: "garlic",
            restResults: [restHit],
            localIngredientResults: [localHit]
        )
        #expect(merged.map(\.id) == [1, 2])
    }

    @Test func duplicateRecipeAcrossSourcesAppearsOnce() {
        let shared = item(7, title: "Garlic Soup", excerpt: "x")
        let merged = SearchResultMerger.merge(
            query: "garlic",
            restResults: [shared],
            localIngredientResults: [shared]
        )
        #expect(merged.count == 1)
        #expect(merged.first?.id == 7)
    }

    @Test func emptySourcesReturnEmptyMerge() {
        let merged = SearchResultMerger.merge(
            query: "anything",
            restResults: [],
            localIngredientResults: []
        )
        #expect(merged.isEmpty)
    }

    private func item(_ id: Int, title: String, excerpt: String) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: title,
            excerpt: excerpt,
            heroImage: nil,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: nil
        )
    }
}
