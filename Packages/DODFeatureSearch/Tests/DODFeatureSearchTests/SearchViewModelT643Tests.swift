import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureSearch

/// CL-121 (T-643) — L1 pipeline coverage for the category-name match path.
/// Each test pins a user-facing contract from CL-121's "what changes" list:
/// `"Dessert Recipes"` surfaces the full Dessert category (regression fix
/// for T-642 / CL-120); `"Chicken"` surfaces Path A + Path B unioned with
/// title matches first; `"Nachos"` is unchanged from REG-29 (Path B empty
/// so the title-precision contract stands alone); Path B failure does NOT
/// block Path A (graceful degradation).
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

    // MARK: - The "Dessert Recipes" contract (the regression T-643 fixes)

    @Test func dessertRecipesSurfacesFullCategory() async {
        // T-642 / CL-120 regression: typing "Dessert Recipes" returned 0
        // items because no individual dessert recipe is titled "Dessert
        // Recipes" — the title-precision filter dropped them all.
        // T-643 / CL-121 fix: Path B fires `?categories=336&per_page=100`
        // and surfaces every dessert. With Path A empty and Path B
        // returning 53, the merged set is 53.
        let dependencies = FakeSearchDependencies()
        dependencies.categories = Self.liveCategories
        // Path A: title-search REST returns the cookbook's actual response
        // for "Dessert Recipes" — basically nothing (the phrase isn't in
        // any recipe title). Empty.
        dependencies.results["Dessert Recipes"] = []
        // Path B: 53 dessert posts in category 336. Titles intentionally
        // don't contain "dessert recipes" — that's the whole point of the
        // regression (these would be dropped by the title filter).
        dependencies.categoryFetchResults[336] = Self.fakeDesserts(count: 53)
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        await viewModel.loadCategoriesIfNeeded()

        viewModel.query = "Dessert Recipes"
        await viewModel.runImmediateSearch()

        #expect(viewModel.state == .results)
        #expect(viewModel.items.count == 53, "All 53 desserts must surface via Path B")
        // The Path B fetch was actually called against the right category.
        #expect(dependencies.categoryFetchCalls.contains { $0.categoryID == 336 })
    }

    // MARK: - The "Chicken" contract — Path A + Path B union

    @Test func chickenUnionsPathAAndPathBDedupedTitleFirst() async {
        // "Chicken" matches Path A (5 chicken-titled posts the title
        // filter accepts) and Path B (32 posts in "Chicken and Poultry
        // Recipes" category id 338). One id (333) overlaps — it's a
        // chicken-titled post that's also in the category. Expected:
        // - title matches come first
        // - the overlap is deduped (counted once, in title-match position)
        // - Path B-only contributions follow
        let dependencies = FakeSearchDependencies()
        dependencies.categories = Self.liveCategories
        let titlePosts = [
            Self.makeItem(101, title: "Chicken Pot Pie"),
            Self.makeItem(102, title: "Bourbon Chicken"),
            Self.makeItem(103, title: "Chicken Marsala"),
            Self.makeItem(104, title: "Chicken Tacos"),
            // 333 is the overlap with Path B below — surfaces as a
            // title match here and as a category match below.
            Self.makeItem(333, title: "Chicken Alfredo Casserole"),
        ]
        dependencies.results["Chicken"] = titlePosts
        let categoryPosts = Self.fakeCategoryPosts(count: 32, idOffset: 300)
        // Insert the overlap id at a known position so the test asserts
        // dedupe regardless of which post happens to land where.
        var withOverlap = categoryPosts
        withOverlap[5] = Self.makeItem(333, title: "Chicken Alfredo Casserole")
        dependencies.categoryFetchResults[338] = withOverlap

        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        await viewModel.loadCategoriesIfNeeded()

        viewModel.query = "Chicken"
        await viewModel.runImmediateSearch()

        #expect(viewModel.state == .results)
        // 5 title-matches + 32 category-matches - 1 overlap = 36 unique ids.
        #expect(viewModel.items.count == 36)
        // Title matches occupy the first 5 positions.
        let firstFiveIds = viewModel.items.prefix(5).map(\.id)
        #expect(Set(firstFiveIds) == Set([101, 102, 103, 104, 333]))
        // No duplicate of 333 in the Path B-only tail.
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

        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        await viewModel.loadCategoriesIfNeeded()

        viewModel.query = "Dessert Recipes"
        await viewModel.runImmediateSearch()

        #expect(viewModel.state == .results, "Path A's title matches must still render")
        #expect(viewModel.items.count == 2)
        // Path B was attempted (the matcher fired) but the throw means
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
