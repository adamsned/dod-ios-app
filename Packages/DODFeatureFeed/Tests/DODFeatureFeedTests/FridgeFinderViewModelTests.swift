import DODDomain
import DODIntelligence
import Foundation
import Testing

@testable import DODFeatureFeed

@MainActor
@Suite("FridgeFinderViewModel (DUT-1978)")
struct FridgeFinderViewModelTests {

    static func recipe(id: Int = 1, lines: [String]) -> Recipe {
        Recipe(
            id: id,
            slug: "recipe-\(id)",
            title: "Recipe \(id)",
            excerpt: "",
            canonicalURL: URL(fileURLWithPath: "/recipe-\(id)"),
            publishedAt: Date(timeIntervalSince1970: 0),
            ingredients: lines.map { RecipeIngredient(text: $0) }
        )
    }

    @Test func nilServiceIsNotAvailable() {
        let viewModel = FridgeFinderViewModel(intelligence: nil, loadRecipes: { [] })
        #expect(!viewModel.isAvailable)
        #expect(!viewModel.supportsImageInput)
        #expect(viewModel.phase == .idle)
    }

    @Test func analyzeWithFakeProducesMatches() async {
        let recipes = [Self.recipe(lines: ["2 eggs", "1 cup flour"])]
        let viewModel = FridgeFinderViewModel(
            intelligence: FakeIntelligenceService(isAvailable: true, ingredients: ["eggs"]),
            loadRecipes: { recipes }
        )
        await viewModel.analyze(imageData: Data([0x01]))

        #expect(viewModel.phase == .results)
        #expect(viewModel.ingredients == ["eggs"])
        #expect(viewModel.matches.count == 1)
    }

    @Test func analyzeUnavailableGoesToNoIngredients() async {
        let recipes = [Self.recipe(lines: ["2 eggs"])]
        let viewModel = FridgeFinderViewModel(
            intelligence: FakeIntelligenceService(isAvailable: false),
            loadRecipes: { recipes }
        )
        await viewModel.analyze(imageData: Data([0x01]))

        #expect(viewModel.phase == .noIngredients)
        #expect(viewModel.ingredients.isEmpty)
        #expect(viewModel.matches.isEmpty)
    }

    @Test func removeIngredientRematches() async {
        let recipes = [
            Self.recipe(id: 1, lines: ["2 eggs"]),
            Self.recipe(id: 2, lines: ["1 cup spinach"]),
        ]
        let viewModel = FridgeFinderViewModel(
            intelligence: FakeIntelligenceService(isAvailable: true, ingredients: ["eggs", "spinach"]),
            loadRecipes: { recipes }
        )
        await viewModel.analyze(imageData: Data([0x01]))
        #expect(viewModel.matches.count == 2)

        await viewModel.removeIngredient("Eggs")
        #expect(viewModel.ingredients == ["spinach"])
        #expect(viewModel.matches.map(\.recipeID) == [2])
        #expect(viewModel.phase == .results)

        await viewModel.removeIngredient("spinach")
        #expect(viewModel.phase == .noIngredients)
        #expect(viewModel.matches.isEmpty)
    }
}
