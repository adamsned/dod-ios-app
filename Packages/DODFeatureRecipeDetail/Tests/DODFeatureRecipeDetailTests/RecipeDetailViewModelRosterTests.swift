import DODDomain
import DODFeatureProfile
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@Suite("RecipeDetailViewModel+Roster")
struct RecipeDetailViewModelRosterTests {
    private func recipe(
        ingredients: [RecipeIngredient] = [],
        servings: Int? = nil,
        suitableForDiet: [String] = []
    ) -> Recipe {
        Recipe(
            id: 1,
            slug: "test-recipe",
            title: "Test Recipe",
            excerpt: "",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/1/") ?? URL(fileURLWithPath: "/"),
            heroImage: nil,
            heroImageLargeURL: nil,
            categoryIDs: [],
            publishedAt: Date(timeIntervalSince1970: 0),
            ingredients: ingredients,
            instructions: [],
            prepTime: nil,
            cookTime: nil,
            totalTime: nil,
            servings: servings,
            nutrition: nil,
            video: nil,
            kind: .recipe,
            articleBodyHTML: nil,
            recipeCategory: [],
            recipeCuisine: [],
            suitableForDiet: suitableForDiet,
            author: nil
        )
    }

    @Test func dairyFlaggedMember() {
        let recipe = recipe(ingredients: [RecipeIngredient(text: "1 cup milk")])
        let member = HouseholdMember(name: "Emma", flags: [.dairy])
        #expect(
            RecipeDetailViewModel.rosterHeadsUps(recipe: recipe, members: [member]) == [
                "Contains dairy - flagged for Emma"
            ]
        )
    }

    @Test func memberWithNoFlags() {
        let recipe = recipe()
        let member = HouseholdMember(name: "Emma")
        #expect(RecipeDetailViewModel.rosterHeadsUps(recipe: recipe, members: [member]).isEmpty)
    }

    @Test func veganDietSkipsDairyFlag() {
        let recipe = recipe(
            ingredients: [RecipeIngredient(text: "1 cup milk")],
            suitableForDiet: ["https://schema.org/VeganDiet"]
        )
        let member = HouseholdMember(name: "Emma", flags: [.dairy])
        #expect(RecipeDetailViewModel.rosterHeadsUps(recipe: recipe, members: [member]).isEmpty)
    }
}
