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
