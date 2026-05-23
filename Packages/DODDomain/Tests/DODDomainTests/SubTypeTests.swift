import Foundation
import Testing

@testable import DODDomain

@Suite("Category value type") struct CategoryTests {
    @Test func codableRoundTrip() throws {
        let original = Category(id: 1590, name: "Latest Recipes", slug: "latest-recipes", count: 312)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Category.self, from: data)
        #expect(decoded == original)
    }
}

@Suite("RecipeIngredient value type") struct RecipeIngredientTests {
    @Test func twoIngredientsWithSameTextAreNotEqualWhenIDsDiffer() {
        let one = RecipeIngredient(text: "1 cup flour")
        let two = RecipeIngredient(text: "1 cup flour")
        #expect(one != two, "Distinct UUIDs mean distinct identities")
    }

    @Test func ingredientWithExplicitIDIsStable() {
        let fixedID = UUID()
        let one = RecipeIngredient(id: fixedID, text: "1 cup flour")
        let two = RecipeIngredient(id: fixedID, text: "1 cup flour")
        #expect(one == two)
    }
}

@Suite("RecipeInstruction value type") struct RecipeInstructionTests {
    @Test func stepNumberIsPreserved() {
        let step = RecipeInstruction(step: 3, text: "Stir vigorously.")
        #expect(step.step == 3)
    }
}

@Suite("RecipeVideo value type") struct RecipeVideoTests {
    @Test func codableRoundTrip() throws {
        let url = URL(string: "https://example.com/video.mp4") ?? URL(filePath: "/dev/null")
        let original = RecipeVideo(url: url, duration: .seconds(120))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RecipeVideo.self, from: data)
        #expect(decoded == original)
    }
}

@Suite("RecipeNutrition value type") struct RecipeNutritionTests {
    @Test func unitfulStringsAreStoredVerbatim() {
        let nutrition = RecipeNutrition(
            calories: "210 kcal",
            servingSize: "1 cup",
            proteinGrams: "5g"
        )
        #expect(nutrition.calories == "210 kcal")
        #expect(nutrition.proteinGrams == "5g")
        #expect(nutrition.fatGrams == nil)
    }
}
