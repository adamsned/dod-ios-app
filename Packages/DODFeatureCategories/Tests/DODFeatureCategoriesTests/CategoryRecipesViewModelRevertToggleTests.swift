import DODDomain
import DODNetworking
import Foundation
import Testing

@testable import DODFeatureCategories

@MainActor
@Suite("CategoryRecipesViewModel Revert Optimistic Toggle (DUT-721)") struct CategoryRecipesRevertToggleTests {

    @Test func revertOptimisticSaveToggleRemovesCurrentlySavedID() async {
        let dependencies = FakeCategoriesDependencies()
        dependencies.posts[1] = (1...5).map(Self.makeItem)
        dependencies.savedIDs = [1, 3]
        let category = DODDomain.Category(id: 336, name: "Desserts", slug: "desserts", count: 5)
        let viewModel = CategoryRecipesViewModel(category: category, dependencies: dependencies)

        await viewModel.onAppear()
        #expect(viewModel.savedRecipeIDs == [1, 3])

        viewModel.revertOptimisticSaveToggle(id: 1)
        #expect(viewModel.savedRecipeIDs == [3])
    }

    @Test func revertOptimisticSaveToggleAddsCurrentlyNotSavedID() async {
        let dependencies = FakeCategoriesDependencies()
        dependencies.posts[1] = (1...5).map(Self.makeItem)
        dependencies.savedIDs = [1, 3]
        let category = DODDomain.Category(id: 336, name: "Desserts", slug: "desserts", count: 5)
        let viewModel = CategoryRecipesViewModel(category: category, dependencies: dependencies)

        await viewModel.onAppear()
        #expect(viewModel.savedRecipeIDs == [1, 3])

        viewModel.revertOptimisticSaveToggle(id: 2)
        #expect(viewModel.savedRecipeIDs == [1, 2, 3])
    }

    @Test func revertOptimisticSaveToggleDoesNotBumpSaveToggleCount() async {
        let dependencies = FakeCategoriesDependencies()
        dependencies.posts[1] = (1...5).map(Self.makeItem)
        dependencies.savedIDs = [1, 3]
        let category = DODDomain.Category(id: 336, name: "Desserts", slug: "desserts", count: 5)
        let viewModel = CategoryRecipesViewModel(category: category, dependencies: dependencies)

        await viewModel.onAppear()
        #expect(viewModel.saveToggleCount == 0)

        viewModel.revertOptimisticSaveToggle(id: 1)
        #expect(viewModel.saveToggleCount == 0)
    }

    @Test func revertOptimisticSaveToggleRoundTripPreservesOriginalState() async {
        let dependencies = FakeCategoriesDependencies()
        dependencies.posts[1] = (1...5).map(Self.makeItem)
        dependencies.savedIDs = [1, 3]
        let category = DODDomain.Category(id: 336, name: "Desserts", slug: "desserts", count: 5)
        let viewModel = CategoryRecipesViewModel(category: category, dependencies: dependencies)

        await viewModel.onAppear()
        #expect(viewModel.savedRecipeIDs == [1, 3])
        #expect(viewModel.saveToggleCount == 0)

        viewModel.applyOptimisticSaveToggle(id: 4)
        #expect(viewModel.savedRecipeIDs == [1, 3, 4])
        #expect(viewModel.saveToggleCount == 1)

        viewModel.revertOptimisticSaveToggle(id: 4)
        #expect(viewModel.savedRecipeIDs == [1, 3])
        #expect(viewModel.saveToggleCount == 1)
    }

    static func makeItem(_ id: Int) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: "R\(id)",
            excerpt: "e",
            heroImage: nil,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: nil
        )
    }
}
