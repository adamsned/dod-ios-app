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

    @Test func fourServingsFourPeopleOneMeatRow() {
        let recipe = Self.recipe(id: 1, title: "Chicken", ingredients: ["1 lb chicken thighs"], servings: 4)
        let estimate = CrowdBudgetEstimator.estimate(recipes: [recipe], headcount: 4)
        #expect(estimate.totalCost == 4.0)
        #expect(estimate.perPersonCost == 1.0)
    }

    @Test func doubleHeadcountDoublesCostAndScale() {
        let recipe = Self.recipe(id: 1, title: "Chicken", ingredients: ["1 lb chicken thighs"], servings: 4)
        let estimate = CrowdBudgetEstimator.estimate(recipes: [recipe], headcount: 8)
        #expect(estimate.totalCost == 8.0)
        #expect(estimate.scaleFactor == 2.0)
    }

    @Test func zeroHeadcountIsClampedToOne() {
        let recipe = Self.recipe(id: 1, title: "Chicken", ingredients: ["1 lb chicken thighs"], servings: 4)
        let estimate = CrowdBudgetEstimator.estimate(recipes: [recipe], headcount: 0)
        #expect(estimate.scaleFactor == 0.25)
        #expect(estimate.totalCost == 1.0)
        #expect(estimate.perPersonCost == 1.0)
    }

    @Test func nilServingsUsesBaseOfFour() {
        let recipe = Self.recipe(id: 1, title: "Chicken", ingredients: ["1 lb chicken thighs"], servings: nil)
        let estimate = CrowdBudgetEstimator.estimate(recipes: [recipe], headcount: 4)
        #expect(estimate.totalCost == 4.0)
        #expect(estimate.scaleFactor == 1.0)
    }

    @Test func emptyRecipesCostNothing() {
        let estimate = CrowdBudgetEstimator.estimate(recipes: [], headcount: 10)
        #expect(estimate == CrowdBudgetEstimator.Estimate(totalCost: 0, perPersonCost: 0, scaleFactor: 1.0))
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
