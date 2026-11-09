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

    @Test func displayItemsPutsPinnedFirstAndSkipsUnknownIDs() async {
        let dependencies = FakeCategoriesDependencies()
        dependencies.posts[1] = (1...5).map(CategoryRecipesViewModelTests.makeItem)
        dependencies.pinned[336] = [4, 2, 99]
        let category = DODDomain.Category(id: 336, name: "Desserts", slug: "desserts", count: 5)
        let viewModel = CategoryRecipesViewModel(category: category, dependencies: dependencies)
        await viewModel.onAppear()
        #expect(viewModel.displayItems.map(\.id) == [4, 2, 1, 3, 5])
    }

    @Test func displayItemsEqualsItemsWithoutPins() async {
        let dependencies = FakeCategoriesDependencies()
        dependencies.posts[1] = (1...5).map(CategoryRecipesViewModelTests.makeItem)
        let category = DODDomain.Category(id: 336, name: "Desserts", slug: "desserts", count: 5)
        let viewModel = CategoryRecipesViewModel(category: category, dependencies: dependencies)
        await viewModel.onAppear()
        #expect(viewModel.displayItems == viewModel.items)
    }

    @Test func heroImageURLUsesFirstDisplayedItemWithAHero() async {
        let dependencies = FakeCategoriesDependencies()
        let hero = URL(string: "https://example.com/h.jpg")
        let withHero = RecipeListItem(
            id: 2,
            title: "R2",
            excerpt: "e",
            heroImage: hero,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: nil
        )
        dependencies.posts[1] = [CategoryRecipesViewModelTests.makeItem(1), withHero]
        let category = DODDomain.Category(id: 336, name: "Desserts", slug: "desserts", count: 2)
        let viewModel = CategoryRecipesViewModel(category: category, dependencies: dependencies)
        await viewModel.onAppear()
        #expect(viewModel.heroImageURL == hero)
    }

    @Test func heroImageURLIsNilWhenNoItemHasAHero() async {
        let dependencies = FakeCategoriesDependencies()
        dependencies.posts[1] = (1...2).map(CategoryRecipesViewModelTests.makeItem)
        let category = DODDomain.Category(id: 336, name: "Desserts", slug: "desserts", count: 2)
        let viewModel = CategoryRecipesViewModel(category: category, dependencies: dependencies)
        await viewModel.onAppear()
        #expect(viewModel.heroImageURL == nil)
    }
}
