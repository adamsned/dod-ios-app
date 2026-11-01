import DODDomain
import Foundation
import Testing

@testable import DODFeatureSaved

@MainActor @Suite("CrowdPlanner (DUT-2021)") struct CrowdPlannerTests {

    @Test func headcountZeroClampsToOne() {
        let planner = CrowdPlanner()
        planner.headcount = 0
        #expect(planner.headcount == 1)
    }

    @Test func emptyRecipesGiveEmptySummary() {
        let planner = CrowdPlanner()
        #expect(planner.summaryText.isEmpty)
    }

    @Test func singleRecipeSummaryText() {
        let planner = CrowdPlanner(headcount: 4)
        planner.recipes = [Self.recipe(id: 1, ingredients: ["1 lb chicken thighs"], servings: 4)]
        #expect(planner.summaryText == "About $4.00 total · $1.00 per person")
    }

    @Test func tipsAreDeduplicatedByText() {
        let planner = CrowdPlanner(headcount: 10)
        planner.recipes = [
            Self.recipe(id: 1, ingredients: ["1 lb chicken thighs"], servings: 4),
            Self.recipe(id: 2, ingredients: ["2 cups broccoli"], servings: 4),
        ]
        let texts = planner.tips.map(\.text)
        #expect(!texts.isEmpty)
        #expect(Set(texts).count == texts.count)
    }

    static func recipe(id: Int, ingredients: [String], servings: Int?) -> Recipe {
        Recipe(
            id: id,
            slug: "r\(id)",
            title: "R\(id)",
            excerpt: "",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/\(id)/") ?? URL(filePath: "/"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            ingredients: ingredients.map { RecipeIngredient(text: $0) },
            instructions: [.init(step: 1, text: "Cook.")],
            servings: servings
        )
    }
}
