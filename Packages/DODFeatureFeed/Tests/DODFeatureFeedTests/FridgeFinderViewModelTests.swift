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
}
