import DODDomain
import Foundation
import Testing

@testable import DODFeatureSaved

@Suite("StretchTips (DUT-2020)") struct StretchTipsTests {

    @Test func headcountAtOrBelowServingsReturnsNoTips() {
        let recipe = Self.recipe(id: 1, ingredients: ["3 lb beef chuck roast"], servings: 4)
        #expect(StretchTips.tips(for: recipe, headcount: 4).isEmpty)
        #expect(StretchTips.tips(for: recipe, headcount: 2).isEmpty)
    }

    @Test func beefRecipeOverServingsGetsBulkAndProteinSwapTips() {
        let recipe = Self.recipe(id: 1, ingredients: ["3 lb beef chuck roast"], servings: 4)
        let tips = StretchTips.tips(for: recipe, headcount: 10)
        #expect(tips.contains { $0.text.hasPrefix("Bulk it up") })
        #expect(tips.contains { $0.text.hasPrefix("Cheaper protein swap") })
    }

    @Test func riceRecipeGetsNoBulkTip() {
        let recipe = Self.recipe(id: 1, ingredients: ["1 cup rice", "3 lb beef chuck roast"], servings: 4)
        let tips = StretchTips.tips(for: recipe, headcount: 10)
        #expect(!tips.contains { $0.text.hasPrefix("Bulk it up") })
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
