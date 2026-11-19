import DODDomain
import DODNetworking
import Foundation
import Testing

@testable import DODFeatureCategories

/// DUT-166 — fake that serves different items for the category fetch and the
/// tag fetch, and records which ids each was asked for.
final class TagModeFakeDependencies: CategoriesDependencies, @unchecked Sendable {
    var categoryItems: [RecipeListItem] = []
    var tagItems: [RecipeListItem] = []
    var categoryIDsRequested: [Int] = []
    var tagIDsRequested: [[Int]] = []

    func fetchCategories() async throws -> [DODDomain.Category] { [] }

    func fetchPosts(
        categoryID: Int,
        page: Int
    ) async throws -> (items: [RecipeListItem], totalPages: Int) {
        categoryIDsRequested.append(categoryID)
        return (categoryItems, 1)
    }

    func fetchPosts(
        tagIDs: [Int],
        page: Int
    ) async throws -> (items: [RecipeListItem], totalPages: Int) {
        tagIDsRequested.append(tagIDs)
        return (tagItems, 1)
    }

    func cache(listItems: [RecipeListItem]) async throws {}

    func cachedListItems(forIDs ids: [Int]) async throws -> [RecipeListItem] {
        let byID = Dictionary(grouping: categoryItems + tagItems, by: \.id).compactMapValues(\.first)
        return ids.compactMap { byID[$0] }
    }
}

@MainActor
@Suite("CategoryRecipesViewModel tag mode (DUT-166)") struct CategoryRecipesViewModelTagModeTests {

    @Test func tagModeCallsTagFetch() async {
        let fake = TagModeFakeDependencies()
        fake.tagItems = [
            CategoryRecipesViewModelTests.makeItem(1),
            CategoryRecipesViewModelTests.makeItem(2),
        ]
        let category = DODDomain.Category(id: 0, name: "Dinner", slug: "dinner", count: 0)
        let viewModel = CategoryRecipesViewModel(
            category: category,
            dependencies: fake
        )
        await viewModel.onAppear()
        #expect(viewModel.items.count == 2)
        #expect(fake.tagIDsRequested == [[12]])
        #expect(fake.categoryIDsRequested.isEmpty)
    }
}
