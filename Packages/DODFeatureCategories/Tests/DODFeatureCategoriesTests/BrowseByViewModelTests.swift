import DODDomain
import Foundation
import Testing

@testable import DODFeatureCategories

struct BrowseTestError: Error {}

final class BrowseByFakeCategoriesDependencies: CategoriesDependencies, @unchecked Sendable {
    var itemsByTagIDs: [[Int]: [RecipeListItem]] = [:]
    var failingTagIDs: Set<[Int]> = []

    func fetchCategories() async throws -> [DODDomain.Category] { [] }

    func fetchPosts(
        categoryID: Int,
        page: Int
    ) async throws -> (items: [RecipeListItem], totalPages: Int) {
        ([], 1)
    }

    func fetchPosts(
        tagIDs: [Int],
        page: Int
    ) async throws -> (items: [RecipeListItem], totalPages: Int) {
        if failingTagIDs.contains(tagIDs) { throw BrowseTestError() }
        return (itemsByTagIDs[tagIDs] ?? [], 1)
    }

    func cache(listItems: [RecipeListItem]) async throws {}

    func cachedListItems(forIDs ids: [Int]) async throws -> [RecipeListItem] { [] }
}

struct FakeAxesProvider: BrowseAxesProviding {
    let result: Result<BrowseAxesConfig, any Error>

    func loadAxes() async throws -> BrowseAxesConfig {
        try result.get()
    }
}
