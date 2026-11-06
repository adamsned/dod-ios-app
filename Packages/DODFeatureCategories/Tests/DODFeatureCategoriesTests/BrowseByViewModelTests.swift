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

@MainActor
@Suite("BrowseByViewModel (DUT-2140)") struct BrowseByViewModelTests {
    static func axis(_ slug: String, _ values: [(String, [Int])]) -> BrowseAxis {
        BrowseAxis(
            slug: slug,
            title: slug.capitalized,
            values: values.map { BrowseAxisValue(slug: $0.0, title: $0.0.capitalized, tagIDs: $0.1) }
        )
    }

    @Test func hidesValuesWithZeroResults() async {
        let deps = BrowseByFakeCategoriesDependencies()
        deps.itemsByTagIDs[[12]] = [CategoryRecipesViewModelTests.makeItem(1)]
        deps.itemsByTagIDs[[13]] = []
        let config = BrowseAxesConfig(axes: [Self.axis("course", [("dinner", [12]), ("lunch", [13])])])
        let viewModel = BrowseByViewModel(provider: FakeAxesProvider(result: .success(config)), dependencies: deps)
        await viewModel.onAppear()
        #expect(viewModel.loadState == .loaded)
        #expect(viewModel.axes.first?.values.map(\.slug) == ["dinner"])
    }
}
