import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@Suite("ImageCardContent")
struct ImageCardContentTests {

    private func recipe(
        cookTime: Duration? = nil,
        totalTime: Duration? = nil,
        servings: Int? = nil,
        canonicalURL: URL = URL(string: "https://www.dutchovendaddy.com/r/1/") ?? URL(fileURLWithPath: "/")
    ) -> Recipe {
        Recipe(
            id: 1,
            slug: "test-recipe",
            title: "Test Recipe",
            excerpt: "",
            canonicalURL: canonicalURL,
            heroImage: nil,
            heroImageLargeURL: nil,
            categoryIDs: [],
            publishedAt: Date(timeIntervalSince1970: 0),
            ingredients: [],
            instructions: [],
            prepTime: nil,
            cookTime: cookTime,
            totalTime: totalTime,
            servings: servings,
            nutrition: nil,
            video: nil,
            kind: .recipe,
            articleBodyHTML: nil,
            recipeCategory: [],
            recipeCuisine: [],
            suitableForDiet: [],
            author: nil
        )
    }

    @Test func testStatsUseCookTimeAndServings() {
        let recipe = self.recipe(cookTime: .seconds(2700), servings: 6)
        let card = ImageCardContent(recipe: recipe)
        #expect(card.stats == ["45 min", "Serves 6"])
    }

    @Test func testStatsFallBackToTotalTime() {
        let recipe = self.recipe(totalTime: .seconds(600))
        let card = ImageCardContent(recipe: recipe)
        #expect(card.stats == ["10 min"])
    }

    @Test func testNoStatsWhenMissing() {
        let recipe = self.recipe()
        let card = ImageCardContent(recipe: recipe)
        #expect(card.stats.isEmpty)
    }

    @Test func testQRPayloadIsCanonicalURL() {
        let url = URL(string: "https://www.dutchovendaddy.com/r/1/")!
        let recipe = self.recipe(canonicalURL: url)
        let card = ImageCardContent(recipe: recipe)
        #expect(card.qrPayload == url.absoluteString)
    }
}
