import DODDomain
import Foundation
import Testing

@testable import DODFeatureSearch

/// v2 Search overhaul (2/3) — type-ahead autocomplete. Suggestions come from
/// the local cached-title pool, computed synchronously per keystroke once the
/// pool is loaded, with a debounce + generation stale-drop so a superseded
/// keystroke can't repaint the list.
@MainActor
@Suite("SearchViewModel — v2 autocomplete")
struct SearchViewModelAutocompleteTests {

    @Test func typingAPrefixYieldsCachedTitleSuggestions() async {
        let dependencies = FakeSearchDependencies()
        dependencies.cachedTitlesArray = [
            "Buttermilk Biscuits",
            "Blueberry Buttermilk Pancakes",
            "Beef Chili",
            "Garlic Bread",
        ]
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )

        viewModel.query = "butter"
        await viewModel.runImmediateAutocomplete()

        #expect(
            viewModel.suggestions == ["Buttermilk Biscuits", "Blueberry Buttermilk Pancakes"],
            "Whole-title prefix ranks above word-prefix; non-matches excluded"
        )
    }

    @Test func shortQueryClearsSuggestions() async {
        let dependencies = FakeSearchDependencies()
        dependencies.cachedTitlesArray = ["Buttermilk Biscuits"]
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )

        viewModel.query = "bu"
        await viewModel.runImmediateAutocomplete()
        #expect(!viewModel.suggestions.isEmpty)

        viewModel.query = "b"  // below the 2-char floor
        await viewModel.runImmediateAutocomplete()
        #expect(viewModel.suggestions.isEmpty)
    }

    @Test func debouncedNewerKeystrokeSupersedesTheOlderPass() async {
        // Stale-drop: a rapid second keystroke cancels the first debounced pass,
        // so only the LATEST query's suggestions ever surface.
        let dependencies = FakeSearchDependencies()
        dependencies.cachedTitlesArray = ["Buttermilk Biscuits", "Beef Chili"]
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        // Pre-load the pool so the passes are timing-deterministic.
        await viewModel.loadTitlePoolIfNeeded()
        viewModel.autocompleteDebounceMilliseconds = 30

        viewModel.query = "beef"  // schedules pass A
        viewModel.query = "butter"  // cancels A, schedules pass B

        for _ in 0..<200 where viewModel.suggestions.isEmpty {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(
            viewModel.suggestions == ["Buttermilk Biscuits"],
            "Only the latest query ('butter') produced suggestions — 'beef' was superseded"
        )
    }

    @Test func applyingASuggestionRunsThatSearchAndClearsTheList() async {
        let dependencies = FakeSearchDependencies()
        dependencies.cachedTitlesArray = ["Buttermilk Biscuits"]
        dependencies.results["Buttermilk Biscuits"] = [
            Self.makeItem(1, title: "Buttermilk Biscuits")
        ]
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        viewModel.debounceMilliseconds = 0
        viewModel.query = "butter"
        await viewModel.runImmediateAutocomplete()
        #expect(!viewModel.suggestions.isEmpty)

        viewModel.applySuggestion("Buttermilk Biscuits")
        #expect(viewModel.query == "Buttermilk Biscuits")
        #expect(viewModel.suggestions.isEmpty, "Tapping a suggestion clears the list")

        // The tapped suggestion runs a real search + records a recent.
        await viewModel.runImmediateSearch()
        #expect(viewModel.items.map(\.id) == [1])
        for _ in 0..<50 where viewModel.recentSearches.isEmpty { await Task.yield() }
        #expect(viewModel.recentSearches.first == "Buttermilk Biscuits")
    }

    @Test func clearWipesSuggestions() async {
        let dependencies = FakeSearchDependencies()
        dependencies.cachedTitlesArray = ["Buttermilk Biscuits"]
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        viewModel.query = "butter"
        await viewModel.runImmediateAutocomplete()
        #expect(!viewModel.suggestions.isEmpty)

        viewModel.clear()
        #expect(viewModel.suggestions.isEmpty)
    }

    // MARK: - Helpers

    static func makeItem(_ id: Int, title: String) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: title,
            excerpt: "Excerpt",
            heroImage: nil,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: nil
        )
    }

    static func scratchRecents() -> RecentSearches {
        let suiteName = "dod.searchAutocompleteTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return RecentSearches(defaults: defaults, storageKey: "recents")
    }
}
