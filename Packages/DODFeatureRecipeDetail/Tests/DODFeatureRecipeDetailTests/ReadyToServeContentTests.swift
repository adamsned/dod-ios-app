import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@Suite("ReadyToServeContent Tests") struct ReadyToServeContentTests {

    /// Helper to create recipes for testing
    static func makeRecipe(
        title: String = "Test Recipe",
        categories: [String] = [],
        steps: [String] = []
    ) -> Recipe {
        Recipe(
            id: 1,
            slug: "test-recipe",
            title: title,
            excerpt: "A test recipe",
            canonicalURL: URL(string: "https://example.com")!,
            categoryIDs: [],
            publishedAt: Date(),
            ingredients: [],
            instructions: steps.map { RecipeInstruction(step: 1, text: $0) },
            totalTime: .seconds(30 * 60),
            servings: 4,
            kind: .recipe
        )
    }

    @Test func breadTitleGivesGoldenBrownCue() {
        let recipe = Self.makeRecipe(title: "Bread Loaf", categories: ["Baking"])
        let content = ReadyToServeContent.make(for: recipe)

        #expect(content.donenessCues.contains("Golden brown on top and edges"))
        #expect(!content.donenessCues.isEmpty)
        #expect(!content.platingTip.isEmpty)
    }

    @Test func chickenStepTextGivesJuicesClearCue() {
        let recipe = Self.makeRecipe(steps: [
            "Season the chicken with salt and pepper", "Roast in oven at 375°F for 45 minutes",
        ])
        let content = ReadyToServeContent.make(for: recipe)

        #expect(content.donenessCues.contains("Juices run clear, not pink"))
        #expect(!content.donenessCues.isEmpty)
        #expect(!content.platingTip.isEmpty)
    }

    @Test func unknownDishGivesGenericCue() {
        let recipe = Self.makeRecipe(title: "Mystery Dish", categories: ["Appetizers"])
        let content = ReadyToServeContent.make(for: recipe)

        #expect(content.donenessCues.contains("It smells fragrant and cooked through"))
        #expect(!content.donenessCues.isEmpty)
        #expect(!content.platingTip.isEmpty)
    }

    @Test func allResultsEndWithTasteCue() {
        let recipe = Self.makeRecipe(title: "Apple Pie")
        let content = ReadyToServeContent.make(for: recipe)

        #expect(content.donenessCues.last == "Taste a small bite and adjust salt if needed")
        #expect(!content.donenessCues.isEmpty)
        #expect(!content.platingTip.isEmpty)
    }

    @Test func dessertGivesProperPlatingTip() {
        let recipe = Self.makeRecipe(title: "Chocolate Cake", categories: ["Desserts"])
        let content = ReadyToServeContent.make(for: recipe)

        #expect(content.platingTip.contains("ice cream") || content.platingTip.contains("whipped cream"))
        #expect(!content.donenessCues.isEmpty)
        #expect(!content.platingTip.isEmpty)
    }

    @Test func stewGivesProperPlatingTip() {
        let recipe = Self.makeRecipe(title: "Beef Stew", steps: ["Brown the beef", "Add vegetables and stock"])
        let content = ReadyToServeContent.make(for: recipe)

        #expect(content.platingTip.contains("warm bowls") && content.platingTip.contains("fresh herbs"))
        #expect(!content.donenessCues.isEmpty)
        #expect(!content.platingTip.isEmpty)
    }
}
