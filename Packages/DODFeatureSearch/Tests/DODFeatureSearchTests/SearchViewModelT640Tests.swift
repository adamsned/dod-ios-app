import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureSearch

/// v2 Search overhaul (3/3) — the "Try" slate invariants after the source
/// swap from WP categories to the curated 100-term `SearchTryChips.pool`.
///
/// The pre-Wave-3 T-640 / CL-118 file guarded a cold-start cache race: the
/// idle view appeared before `loadCategoriesIfNeeded()` resolved, so the
/// first read of `displayedTrySlate` could see an empty `availableCategories`
/// and cache a partial 1-pill slate forever. That race is **gone** — the pool
/// is now a constant array that never depends on the async category fetch, so
/// the very first read is always a full slate. These tests pin the new
/// invariants (full-on-first-read + stable-within-session) and keep the
/// "Uncategorized" exclusion coverage, now retargeted to `browseCategories`
/// (which still derives from `availableCategories`).
///
/// Split into a separate file so `SearchViewModelTests.swift` stays under
/// SwiftLint's `file_length` / `type_body_length` caps.
@MainActor
@Suite("SearchViewModel Try slate + browse (v2 Search overhaul 3/3)") struct SearchViewModelT640Tests {

    @Test func slateIsFullOnFirstReadWithoutCategoryLoad() async {
        // Wave 3: the slate no longer waits on `loadCategoriesIfNeeded()`.
        // A fresh viewmodel with no categories loaded still returns a full
        // slate (pinned Latest Recipes + 9 curated chips) on the first read.
        let viewModel = SearchViewModel(
            dependencies: FakeSearchDependencies(),
            recentSearches: Self.scratchRecents()
        )
        let slate = viewModel.displayedTrySlate
        #expect(slate.count == SearchViewModel.trySlateVisibleCount)
        #expect(slate.first?.isLatestRecipes == true)
    }

    @Test func fullSlateCachesAndIsStableAcrossReads() async {
        // Once a full-count slate caches, subsequent reads return the same
        // slate (the shuffle does not re-fire) — the stable-within-session
        // contract, restated for the constant-pool source.
        let viewModel = SearchViewModel(
            dependencies: FakeSearchDependencies(),
            recentSearches: Self.scratchRecents()
        )
        let first = viewModel.displayedTrySlate
        let second = viewModel.displayedTrySlate
        #expect(first.count == SearchViewModel.trySlateVisibleCount)
        #expect(first.map(\.id) == second.map(\.id))
    }

    // MARK: - T-641 / CL-119 — Uncategorized exclusion (browse list)

    @Test func browseCategories_excludes_uncategorized() async {
        // T-641 / CL-119: the browse "Categories" list must drop the
        // "Uncategorized" WP category (and the synthetic Latest Recipes feed)
        // before rendering. Fixture: an Uncategorized + a Latest Recipes entry
        // plus 5 real categories — browse must return only the 5 real ones.
        let dependencies = FakeSearchDependencies()
        dependencies.categories = [
            DODDomain.Category(id: 1590, name: "Latest Recipes", slug: "latest-recipes", count: 100),
            DODDomain.Category(id: 9999, name: "Uncategorized", slug: "uncategorized", count: 1),
            DODDomain.Category(id: 101, name: "Beef", slug: "beef", count: 50),
            DODDomain.Category(id: 102, name: "Pork", slug: "pork", count: 40),
            DODDomain.Category(id: 103, name: "Chicken", slug: "chicken", count: 30),
            DODDomain.Category(id: 104, name: "Sides", slug: "sides", count: 20),
            DODDomain.Category(id: 105, name: "Desserts", slug: "desserts", count: 10),
        ]
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        await viewModel.loadCategoriesIfNeeded()

        let browse = viewModel.browseCategories
        #expect(browse.count == 5)
        #expect(!browse.contains(where: { $0.slug == "uncategorized" }))
        #expect(!browse.contains(where: { $0.id == 1590 }))
    }

    @Test func browseCategories_exclusion_is_case_insensitive_on_slug() async {
        // T-641 / CL-119: the exclusion-set lookup applies `$0.slug.lowercased()`
        // to the category side, so an upper-case-bearing slug like
        // "Uncategorized" is still filtered. Pin that contract.
        let dependencies = FakeSearchDependencies()
        dependencies.categories = [
            DODDomain.Category(id: 9999, name: "Uncategorized", slug: "Uncategorized", count: 1),
            DODDomain.Category(id: 101, name: "Beef", slug: "beef", count: 50),
        ]
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        await viewModel.loadCategoriesIfNeeded()

        let browse = viewModel.browseCategories
        #expect(browse.count == 1)
        #expect(browse.first?.slug == "beef")
    }

    // MARK: - Fixtures

    /// Per-test isolated UserDefaults so the disk-backed history doesn't leak
    /// between tests on the same machine. Mirrors the existing
    /// `SearchViewModelTests.scratchRecents()` helper.
    static func scratchRecents() -> RecentSearches {
        let suiteName = "dod.searchT640Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return RecentSearches(defaults: defaults, storageKey: "recents")
    }
}
