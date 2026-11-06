import DODDomain
import Foundation
import Testing

@testable import DODFeatureCategories

@MainActor
@Suite("CategoryRecipesViewModel pinned (DUT-161)") struct CategoryRecipesViewModelPinnedTests {

    @Test func onAppearLoadsPinnedIDs() async {
        let dependencies = FakeCategoriesDependencies()
        dependencies.posts[1] = (1...5).map(CategoryRecipesViewModelTests.makeItem)
        dependencies.pinned[336] = [4, 2, 99]
        let category = DODDomain.Category(id: 336, name: "Desserts", slug: "desserts", count: 5)
        let viewModel = CategoryRecipesViewModel(category: category, dependencies: dependencies)
        await viewModel.onAppear()
        #expect(viewModel.pinnedIDs == [4, 2, 99])
    }
}
