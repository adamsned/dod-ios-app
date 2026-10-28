import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureSaved

@MainActor
@Suite("CrowdBudgetEstimator (DUT-2019)") struct CrowdBudgetEstimatorTests {

    @Test func baseServingsUsesRecipeServings() {
        let recipe = Self.recipe(id: 1, title: "A", ingredients: [], servings: 6)
        #expect(CrowdBudgetEstimator.baseServings(for: recipe) == 6)
    }

    @Test func baseServingsFallsBackToFourWhenNil() {
        let recipe = Self.recipe(id: 1, title: "A", ingredients: [], servings: nil)
        #expect(CrowdBudgetEstimator.baseServings(for: recipe) == 4)
    }

    @Test func baseServingsFallsBackToFourWhenNonPositive() {
        let recipe = Self.recipe(id: 1, title: "A", ingredients: [], servings: 0)
        #expect(CrowdBudgetEstimator.baseServings(for: recipe) == 4)
    }

    // MARK: - Fixtures

    static func recipe(id: Int, title: String, ingredients: [String], servings: Int?) -> Recipe {
        Recipe(
            id: id,
            slug: "r\(id)",
            title: title,
            excerpt: "",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/\(id)/") ?? URL(filePath: "/"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            ingredients: ingredients.map { RecipeIngredient(text: $0) },
            instructions: [.init(step: 1, text: "Cook.")],
            servings: servings
        )
    }
}
