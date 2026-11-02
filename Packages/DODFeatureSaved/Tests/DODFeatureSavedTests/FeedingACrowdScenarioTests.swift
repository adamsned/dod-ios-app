import DODDomain
import Foundation
import Testing

@testable import DODFeatureSaved

@MainActor
@Suite("Feeding a crowd (DUT-997)") struct FeedingACrowdScenarioTests {

    @Test func youthGroupOfThirtyScalesPotRoastAndSuggestsStretching() {
        let roast = Self.recipe(
            id: 1,
            title: "Pot Roast",
            servings: 6,
            ingredients: ["3 lb beef chuck roast", "1 yellow onion"]
        )
        let planner = CrowdPlanner(headcount: 30)
        planner.recipes = [roast]

        #expect(planner.estimate.scaleFactor == 5.0)
        #expect(planner.estimate.perPersonCost > 0)
        #expect(planner.tips.contains { $0.text.contains("Bulk it up") })
        #expect(planner.tips.contains { $0.text.contains("Cheaper protein swap") })
    }

    @Test func smallHouseholdGetsNoTips() {
        let roast = Self.recipe(id: 1, title: "Pot Roast", servings: 6, ingredients: ["3 lb beef chuck roast"])
        let planner = CrowdPlanner(headcount: 4)
        planner.recipes = [roast]
        #expect(planner.tips.isEmpty)
    }

    static func recipe(id: Int, title: String, servings: Int, ingredients: [String]) -> Recipe {
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
