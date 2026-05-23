import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureSearch

@MainActor
@Suite("SearchViewModel (T-100..T-103)") struct SearchViewModelTests {

    @Test func shortQueriesAreIgnored() async {
        let dependencies = FakeSearchDependencies()
        let viewModel = SearchViewModel(dependencies: dependencies)
        viewModel.debounceMilliseconds = 0
        viewModel.query = "a"
        try? await Task.sleep(nanoseconds: 5_000_000)
        #expect(viewModel.state == .idle)
        #expect(dependencies.searches.isEmpty)
    }

    @Test func successfulSearchPopulatesItems() async {
        let dependencies = FakeSearchDependencies()
        dependencies.results["pasta"] = [Self.makeItem(1), Self.makeItem(2)]
        let viewModel = SearchViewModel(dependencies: dependencies)
        viewModel.query = "pasta"
        await viewModel.runImmediateSearch()
        #expect(viewModel.state == .results)
        #expect(viewModel.items.count == 2)
    }

    @Test func emptyResultSetTransitionsToNoResults() async {
        let dependencies = FakeSearchDependencies()
        let viewModel = SearchViewModel(dependencies: dependencies)
        viewModel.query = "zzz"
        await viewModel.runImmediateSearch()
        #expect(viewModel.state == .noResults)
    }

    @Test func offlineShortCircuitsBeforeNetwork() async {
        let dependencies = FakeSearchDependencies()
        dependencies.online = false
        let viewModel = SearchViewModel(dependencies: dependencies)
        viewModel.query = "anything"
        await viewModel.runImmediateSearch()
        #expect(viewModel.state == .offline)
        #expect(dependencies.searches.isEmpty)
    }

    @Test func clearResetsState() async {
        let dependencies = FakeSearchDependencies()
        dependencies.results["something"] = [Self.makeItem(1)]
        let viewModel = SearchViewModel(dependencies: dependencies)
        viewModel.query = "something"
        await viewModel.runImmediateSearch()
        viewModel.clear()
        #expect(viewModel.state == .idle)
        #expect(viewModel.items.isEmpty)
        #expect(viewModel.query.isEmpty)
    }

    @Test func telemetrySendsHashedQueryNotRaw() async {
        let dependencies = FakeSearchDependencies()
        dependencies.results["secret query"] = []
        let viewModel = SearchViewModel(dependencies: dependencies)
        viewModel.query = "secret query"
        await viewModel.runImmediateSearch()
        let sent = try? #require(dependencies.searchHashes.first)
        let expected = StringHasher.sha256Hex("secret query")
        #expect(sent == expected)
        // The raw text must never reach analytics.
        #expect(!(sent ?? "").contains("secret"))
    }

    static func makeItem(_ id: Int) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: "Match \(id)",
            excerpt: "Excerpt",
            heroImage: nil,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: nil
        )
    }
}

final class FakeSearchDependencies: SearchDependencies, @unchecked Sendable {
    var results: [String: [RecipeListItem]] = [:]
    var online = true
    var searches: [String] = []
    var searchHashes: [String] = []

    func search(query: String) async throws -> [RecipeListItem] {
        searches.append(query)
        return results[query] ?? []
    }

    func cache(listItems: [RecipeListItem]) async throws {}

    func sendSearchTelemetry(queryHash: String) async {
        searchHashes.append(queryHash)
    }

    func isOnline() async -> Bool { online }
}
