import DODDomain
import Foundation
import Testing

@testable import DODFeatureSearch

/// DUT-1233 regression coverage: tapping a "Try Searching" pill for a
/// collection-style category (e.g. "Fall Favorites") used to run a literal
/// full-text search for the category's name, which returned "No recipes
/// match" for every category whose name never appears literally in an
/// individual recipe's title. Confirmed live against the WP category list
/// that this affects more than one category: "Fall Favorites", "Memorial Day
/// Recipes", "Easter Recipes", "Holiday Recipes", "Thanksgiving Recipes",
/// "Cinco De Mayo", and "New Year's Eve Recipes" all share this shape.
/// `SearchView.categoryTapAction(for:)` now routes every category except
/// "Latest Recipes" (which keeps its own bespoke feed-fetch surface) through
/// a category BROWSE instead, matching what the "Categories" section's rows
/// already do.
@Suite("SearchView.categoryTapAction(for:) (DUT-1233)")
struct SearchViewCategoryTapTests {

    /// "Latest Recipes" (by id) is the one carve-out that keeps its bespoke
    /// feed-fetch behavior — not affected by the DUT-1233 fix.
    @Test func latestRecipesByIdSurfacesLatestRecipes() {
        let category = DODDomain.Category(id: 1590, name: "Renamed Category", slug: "latest", count: 1)
        #expect(SearchView.categoryTapAction(for: category) == .surfaceLatestRecipes)
    }

    /// "Latest Recipes" (by name, non-1590 id) also keeps the carve-out —
    /// matches `isLatestRecipesCategory`'s own disjunctive contract.
    @Test func latestRecipesByNameSurfacesLatestRecipes() {
        let category = DODDomain.Category(id: 42, name: "Latest Recipes", slug: "latest-recipes", count: 1)
        #expect(SearchView.categoryTapAction(for: category) == .surfaceLatestRecipes)
    }

    /// THE regression case: "Fall Favorites" — the exact category Ned
    /// reported (WP id 1579, confirmed live) — now browses instead of
    /// running a literal search that returned "No recipes match".
    @Test func fallFavoritesBrowsesCategory() {
        let category = DODDomain.Category(id: 1579, name: "Fall Favorites", slug: "fall-favorites", count: 18)
        #expect(SearchView.categoryTapAction(for: category) == .browseCategory)
    }

    /// Every other confirmed-live collection-style category with the same
    /// shape also browses, not just the one Ned happened to report.
    @Test(
        "other collection-style categories browse, not search",
        arguments: [
            "Memorial Day Recipes",
            "Easter Recipes",
            "Holiday Recipes",
            "Thanksgiving Recipes",
            "Cinco De Mayo",
            "New Year's Eve Recipes",
        ]
    )
    func otherCollectionStyleCategoriesBrowseCategory(name: String) {
        let category = DODDomain.Category(id: 9999, name: name, slug: "slug", count: 10)
        #expect(SearchView.categoryTapAction(for: category) == .browseCategory)
    }

    /// A genuinely searchable topic keyword (the kind `selectCuratedSuggestion`
    /// was originally designed for) ALSO now browses under the DUT-1233
    /// general fix — Ned's chosen fix routes every non-"Latest Recipes"
    /// category through browse uniformly, not just the collection-style ones.
    @Test func ordinaryTopicCategoryAlsoBrowsesCategory() {
        let category = DODDomain.Category(id: 336, name: "Dessert Recipes", slug: "dessert-recipes", count: 56)
        #expect(SearchView.categoryTapAction(for: category) == .browseCategory)
    }
}
