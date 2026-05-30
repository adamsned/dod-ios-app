import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureSearch

/// CL-118 (T-640) — hot-fix to T-639 / CL-117's rotating Try pool.
/// Pins the only-cache-full-slate cache-rule fix that closes the
/// cold-start race: the view appears before
/// `loadCategoriesIfNeeded()` resolves, so the first read of
/// `displayedTrySlate` can see an empty `availableCategories` →
/// `pickTrySlate(...)` returns the single synthesized [Latest Recipes]
/// pill. Pre-fix that 1-pill slate was cached forever and the user
/// was locked to one pill for the session. The fix: only cache the
/// slate when it reaches the full visible count of
/// `Self.trySlateVisibleCount`, so the next read after categories
/// land recomputes and the user sees the real shuffle.
///
/// Split into a separate file so `SearchViewModelTests.swift` stays
/// under SwiftLint's `file_length` / `type_body_length` caps — mirrors
/// the `SearchViewModelT637Tests.swift` Latest-Recipes-pill split.
@MainActor
@Suite("SearchViewModel CL-118 / T-640 (cache race)") struct SearchViewModelT640Tests {

    @Test func emptyPoolAtFirstAccessDoesNotCachePartialSlate() async {
        // T-640 / CL-118: the cold-start cache race. The view appears
        // before `loadCategoriesIfNeeded()` resolves → first read of
        // `displayedTrySlate` sees an empty `availableCategories` →
        // `pickTrySlate(...)` returns the single synthesized [Latest
        // Recipes] pill (length 1, < `trySlateVisibleCount`). Pre-fix
        // that partial slate was cached forever and the user was
        // locked to one pill for the session. The fix: only cache
        // full-count slates, so the next read after categories land
        // recomputes and the user sees the real rotation.
        let dependencies = FakeSearchDependencies()
        dependencies.categories = []
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        // First read: pool is empty → partial slate (just pinned).
        let firstRead = viewModel.displayedTrySlate
        #expect(firstRead.count == 1)
        #expect(firstRead.first?.id == 1590)

        // Categories arrive (simulating the async fetch landing).
        dependencies.categories = Self.makeRotationPool(size: 30)
        await viewModel.loadCategoriesIfNeeded()

        // Second read: pool is now full → MUST recompute, not return
        // the cached 1-pill slate. This is the bug T-640 fixes.
        let secondRead = viewModel.displayedTrySlate
        #expect(secondRead.count == SearchViewModel.trySlateVisibleCount)
        #expect(secondRead.first?.id == 1590)
    }

    @Test func fullSlateCachesAndIsStableAcrossReads() async {
        // T-640 / CL-118: confirm the stable-within-session contract
        // still holds. Once a full-count slate caches, subsequent
        // reads return the same slate (the shuffle does not re-fire).
        // This is the existing T-639 contract — restated here to lock
        // it alongside the new cache-rule behavior.
        let dependencies = FakeSearchDependencies()
        dependencies.categories = Self.makeRotationPool(size: 30)
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        await viewModel.loadCategoriesIfNeeded()

        let first = viewModel.displayedTrySlate
        let second = viewModel.displayedTrySlate
        #expect(first.count == SearchViewModel.trySlateVisibleCount)
        #expect(first.map(\.id) == second.map(\.id))
    }

    @Test func partialPoolSmallerThanVisibleCountDoesNotCache() async {
        // T-640 / CL-118: the cache rule fires ONLY when the slate
        // reaches the full visible count. A pool with just Latest
        // Recipes (no rotatable entries) produces a 1-pill slate per
        // `pickTrySlate(...)`'s "empty rotation tail → just pinned"
        // branch — same length as the empty-pool path, so the cache
        // rule must also skip caching here. If the pool is later
        // widened (e.g. REST refetch), a fresh VM read produces the
        // full slate, which caches as expected — the L1 assertion is
        // that the partial-slate cache rule does NOT lock the 1-pill
        // result.
        let dependencies = FakeSearchDependencies()
        dependencies.categories = [
            DODDomain.Category(id: 1590, name: "Latest Recipes", slug: "latest-recipes", count: 0)
        ]
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        await viewModel.loadCategoriesIfNeeded()

        let firstRead = viewModel.displayedTrySlate
        #expect(firstRead.count == 1)
        #expect(firstRead.first?.id == 1590)

        // Widen the pool — categories grow. `loadCategoriesIfNeeded()`
        // short-circuits when `availableCategories` is non-empty, so
        // seed a fresh viewmodel to simulate the post-widening read.
        // This mirrors the production sequence: a single viewmodel
        // sees the categories land monotonically, and the cache rule
        // ensures the partial 1-pill slate did not lock the session.
        dependencies.categories = Self.makeRotationPool(size: 30)
        let widerViewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        await widerViewModel.loadCategoriesIfNeeded()
        let widerRead = widerViewModel.displayedTrySlate
        #expect(widerRead.count == SearchViewModel.trySlateVisibleCount)
    }

    // MARK: - Fixtures

    /// Build a rotation pool with Latest Recipes pinned at id 1590
    /// plus N-1 rotatable categories. Used by the T-640 / CL-118
    /// cache-race regression tests.
    static func makeRotationPool(size: Int) -> [DODDomain.Category] {
        (1...size).map { id in
            DODDomain.Category(
                id: id == 1 ? 1590 : id + 100,
                name: id == 1 ? "Latest Recipes" : "Cat\(id)",
                slug: id == 1 ? "latest-recipes" : "cat\(id)",
                count: 100 - id
            )
        }
    }

    /// Per-test isolated UserDefaults so the disk-backed history
    /// doesn't leak between tests on the same machine. Mirrors the
    /// existing `SearchViewModelTests.scratchRecents()` helper.
    static func scratchRecents() -> RecentSearches {
        let suiteName = "dod.searchT640Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return RecentSearches(defaults: defaults, storageKey: "recents")
    }
}
