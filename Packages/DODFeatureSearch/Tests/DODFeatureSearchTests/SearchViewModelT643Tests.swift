import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureSearch

/// CL-121 (T-643) — L1 pipeline coverage for the category-name match path,
/// updated for DUT-574's Path B gate.
///
/// DUT-574: Path B (the `?categories=<id>&per_page=100` category fetch) no
/// longer fires off the *typed query text* naming a category — that fired up
/// to two 100-post round-trips on every finalized plain-text search and
/// polluted results with unrelated recent category posts (the user-reported
/// "slow + doesn't work right" bug). Path B now fires ONLY when a category
/// filter chip is actually set (`filters.categoryID != nil`). These tests are
/// updated accordingly: the plain-text "Dessert Recipes" / "Chicken" cases
/// now assert NO category fan-out, and a dedicated filter-active test proves
/// Path B still fires + unions when the filter IS set. `"Nachos"` (Path B
/// naturally empty) and the graceful-degradation contract are unchanged.
///
/// Split into its own file so `SearchViewModelTests.swift` stays under
/// SwiftLint's `file_length` cap — mirrors T-637 / T-640's split pattern.
@MainActor
@Suite("SearchViewModel CL-121 / T-643") struct SearchViewModelT643Tests {

    // MARK: - Live-API top-8 category fixture (2026-05-30)

    /// Same eight categories the `CategoryNameMatcherTests` suite uses
    /// (from CL-121's rationale section). Pre-loaded into the viewmodel
    /// via `dependencies.categories = ...` + `loadCategoriesIfNeeded()`.
    static let liveCategories: [DODDomain.Category] = [
        DODDomain.Category(id: 1590, name: "Latest Recipes", slug: "latest-recipes", count: 240),
        DODDomain.Category(id: 336, name: "Dessert Recipes", slug: "dessert-recipes", count: 53),
        DODDomain.Category(id: 1435, name: "One Pot Dutch Oven Recipes", slug: "one-pot-dutch-oven-recipes", count: 46),
        DODDomain.Category(
            id: 338,
            name: "Chicken and Poultry Recipes",
            slug: "chicken-and-poultry-recipes",
            count: 32
        ),
        DODDomain.Category(id: 339, name: "Beef and Red Meat Recipes", slug: "beef-and-red-meat-recipes", count: 28),
        DODDomain.Category(id: 334, name: "Side Dish Recipes", slug: "side-dish-recipes", count: 28),
        DODDomain.Category(id: 777, name: "Breads and Pizza Recipes", slug: "breads-and-pizza-recipes", count: 27),
        DODDomain.Category(id: 337, name: "Dutch Oven Camp Recipes", slug: "dutch-oven-camp-recipes", count: 26),
    ]

    // MARK: - DUT-574: a plain text search never fires the category fan-out

    @Test func plainTextSearchNamingACategoryDoesNotFirePathB() async {
        // DUT-574 (was `dessertRecipesSurfacesFullCategory`): typing the
        // category name "Dessert Recipes" with NO category filter set must
        // make exactly ONE primary request (Path A) and never fire the
        // `?categories=336&per_page=100` fan-out. The pre-DUT-574 code fired
        // Path B off the query text, pulling the whole 53-post category into
        // the results even though the user only typed text — the slowness +
        // "doesn't work right" bug. With Path A empty, the result is empty.
        let dependencies = FakeSearchDependencies()
        dependencies.categories = Self.liveCategories
        dependencies.results["Dessert Recipes"] = []
        // Seeded but must NOT be fetched — no filter is set.
        dependencies.categoryFetchResults[336] = Self.fakeDesserts(count: 53)
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        await viewModel.loadCategoriesIfNeeded()

        viewModel.query = "Dessert Recipes"
        await viewModel.runImmediateSearch()

        #expect(
            dependencies.categoryFetchCalls.isEmpty,
            "Plain text search must not fire the category fan-out (DUT-574)"
        )
        // Exactly one primary REST call for the finalized search.
        #expect(dependencies.searches == ["Dessert Recipes"])
        #expect(viewModel.items.isEmpty)
    }

    // MARK: - DUT-574: Path B still fires + unions when a category filter IS set

    @Test func categoryFilterSetFiresPathBAndUnionsTitleFirst() async {
        // DUT-574 (adapted from `chickenUnionsPathAAndPathBDedupedTitleFirst`):
        // with the "Chicken and Poultry Recipes" category filter (id 338)
        // actually set, Path B fires and unions with Path A — title matches
        // first, category-only contributions after, overlap deduped. The
        // filter's post-filter narrows to recipes tagged with category 338,
        // so every surfaced id is mapped to 338 in `categoryMap`.
        let dependencies = FakeSearchDependencies()
        dependencies.categories = Self.liveCategories
        let titlePosts = [
            Self.makeItem(101, title: "Chicken Pot Pie"),
            Self.makeItem(102, title: "Bourbon Chicken"),
            Self.makeItem(103, title: "Chicken Marsala"),
            Self.makeItem(104, title: "Chicken Tacos"),
            // 333 overlaps with Path B below.
            Self.makeItem(333, title: "Chicken Alfredo Casserole"),
        ]
        dependencies.results["Chicken"] = titlePosts
        let categoryPosts = Self.fakeCategoryPosts(count: 32, idOffset: 300)
        var withOverlap = categoryPosts
        withOverlap[5] = Self.makeItem(333, title: "Chicken Alfredo Casserole")
        dependencies.categoryFetchResults[338] = withOverlap
        // Tag every surfaced id with category 338 so the post-filter admits
        // them (the filter narrows the union to the filtered category).
        var categoryMap: [Int: [Int]] = [:]
        for item in titlePosts + withOverlap { categoryMap[item.id] = [338] }
        dependencies.categoryMap = categoryMap

        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        await viewModel.loadCategoriesIfNeeded()
        // The actually-set filter is what unlocks Path B now.
        viewModel.filters.categoryID = 338

        viewModel.query = "Chicken"
        await viewModel.runImmediateSearch()

        #expect(viewModel.state == .results)
        #expect(dependencies.categoryFetchCalls.contains { $0.categoryID == 338 })
        // 5 title-matches + 32 category-matches - 1 overlap = 36 unique ids.
        #expect(viewModel.items.count == 36)
        let firstFiveIds = viewModel.items.prefix(5).map(\.id)
        #expect(Set(firstFiveIds) == Set([101, 102, 103, 104, 333]))
        #expect(viewModel.items.filter { $0.id == 333 }.count == 1)
    }

    // MARK: - "Nachos" contract — T-642 / REG-29 preserved

    @Test func nachosUnchangedFromT642Contract() async {
        // The Nacho-Bug fix's title-precision contract must not regress.
        // "Nachos" doesn't name any category, so Path B returns []. Path
        // A returns the 4 known nacho-titled posts (per CL-120's live-API
        // truth). Final result set: 4, exactly the T-642 baseline.
        let dependencies = FakeSearchDependencies()
        dependencies.categories = Self.liveCategories
        let nachoTitles = [
            Self.makeItem(524, title: "Super Nacho Dip"),
            Self.makeItem(274, title: "Tater Tot Nachos"),
            Self.makeItem(5016, title: "Pulled Pork Nachos"),
            Self.makeItem(736, title: "Cast Iron Skillet Nachos"),
        ]
        dependencies.results["Nachos"] = nachoTitles
        // No `categoryFetchResults[...]` seeded — confirms the matcher
        // returns [] and the viewmodel doesn't call Path B.

        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        await viewModel.loadCategoriesIfNeeded()

        viewModel.query = "Nachos"
        await viewModel.runImmediateSearch()

        #expect(viewModel.state == .results)
        #expect(viewModel.items.count == 4, "Exactly the four known nacho titles, no category contribution")
        #expect(
            dependencies.categoryFetchCalls.isEmpty,
            "Path B must short-circuit when no category matches — no wasted REST call"
        )
    }

    // MARK: - Path B failure → Path A still renders

    @Test func pathBFailureFallsBackToPathAResults() async {
        // The category-match fetch errors (REST down, network blip).
        // Path A's 53 dessert-titled posts (fabricated for this test —
        // not real on the live API, but valid for the fixture: any post
        // whose title literally contains "Dessert Recipes" would surface)
        // must still render. The user gets degraded but non-empty results
        // instead of a hard offline screen.
        let dependencies = FakeSearchDependencies()
        dependencies.categories = Self.liveCategories
        let pathATitles = [
            Self.makeItem(1, title: "Dessert Recipes Roundup"),
            Self.makeItem(2, title: "30 Best Dessert Recipes Ever"),
        ]
        dependencies.results["Dessert Recipes"] = pathATitles
        dependencies.categoryFetchResults[336] = Self.fakeDesserts(count: 53)
        // Force Path B to throw so the union sees only Path A.
        dependencies.categoryFetchShouldThrow = true
        // DUT-574: Path B only fires with a filter set — tag the Path A titles
        // with category 336 so the post-filter admits them once they render.
        dependencies.categoryMap = [1: [336], 2: [336]]

        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        await viewModel.loadCategoriesIfNeeded()
        // DUT-574: the set filter unlocks Path B (which then throws).
        viewModel.filters.categoryID = 336

        viewModel.query = "Dessert Recipes"
        await viewModel.runImmediateSearch()

        #expect(viewModel.state == .results, "Path A's title matches must still render")
        #expect(viewModel.items.count == 2)
        // Path B was attempted (the filter fired it) but the throw means
        // no posts contributed.
        #expect(dependencies.categoryFetchCalls.contains { $0.categoryID == 336 })
    }

    // MARK: - Helpers

    /// Build N fake dessert posts whose titles deliberately do NOT contain
    /// "Dessert Recipes" — that's the regression contract. Use the actual
    /// kind of titles the live category contains: dish names.
    static func fakeDesserts(count: Int) -> [RecipeListItem] {
        let titlePool = [
            "Apple Crumble", "Cherry Cobbler", "Sticky Toffee Pudding",
            "Brown Butter Skillet Brownies", "Dutch Apple Pie",
            "Campfire S'mores Dip", "Skillet Peach Cobbler",
            "Cast Iron Chocolate Chip Cookie", "Bread Pudding",
            "Pineapple Upside Down Cake",
        ]
        return (0..<count).map { idx in
            let title = titlePool[idx % titlePool.count]
            return RecipeListItem(
                id: 10_000 + idx,
                title: "\(title) #\(idx)",
                excerpt: "Excerpt",
                heroImage: nil,
                publishedAt: Date(timeIntervalSince1970: TimeInterval(1_700_000_000 - idx * 86400)),
                totalTimeDisplay: nil
            )
        }
    }

    /// Build N fake category posts with deterministic ids starting at
    /// `idOffset`. Titles intentionally do NOT contain "Chicken" so the
    /// title-precision filter would drop them — that's the whole point
    /// of Path B existing.
    static func fakeCategoryPosts(count: Int, idOffset: Int) -> [RecipeListItem] {
        let titlePool = [
            "Lemon Pepper Wings", "Buttermilk Wings", "Cornish Game Hen",
            "Quail Confit", "Turkey Tetrazzini", "Bourbon Wings",
            "Duck a l'Orange", "Pheasant Pot Pie", "Roast Turkey",
            "Cast Iron Wings",
        ]
        return (0..<count).map { idx in
            let title = titlePool[idx % titlePool.count]
            return RecipeListItem(
                id: idOffset + idx,
                title: "\(title) #\(idx)",
                excerpt: "Excerpt",
                heroImage: nil,
                publishedAt: Date(timeIntervalSince1970: TimeInterval(1_700_000_000 - idx * 86400)),
                totalTimeDisplay: nil
            )
        }
    }

    static func makeItem(_ id: Int, title: String = "Match") -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: title,
            excerpt: "Excerpt",
            heroImage: nil,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: nil
        )
    }

    /// Per-test isolated UserDefaults so the disk-backed history doesn't
    /// leak between tests on the same machine. Mirrors the helper in
    /// `SearchViewModelTests.swift` so this file doesn't have to import it.
    static func scratchRecents() -> RecentSearches {
        let suiteName = "dod.searchT643Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return RecentSearches(defaults: defaults, storageKey: "recents")
    }
}
