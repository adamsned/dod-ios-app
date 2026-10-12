import DODDomain
import Foundation
import Testing

@testable import DODFeatureSearch

@Suite("SearchViewModel.isLatestRecipesCategory(_:)")
struct IsLatestRecipesCategoryTests {
    /// Branch 1 coverage: id == 1590 works even if the category name is different.
    /// This verifies the id fallback path when a category was renamed server-side.
    @Test("id match: 1590 with non-standard name")
    func idMatchWithRenamedCategory() {
        let category = DODDomain.Category(
            id: 1590,
            name: "Renamed Category",
            slug: "renamed-category",
            count: 1
        )
        #expect(SearchViewModel.isLatestRecipesCategory(category) == true)
    }

    /// Branch 1 edge case: id == 1590 with the canonical name still works.
    @Test("id match: 1590 with canonical name")
    func idMatchWithCanonicalName() {
        let category = DODDomain.Category(
            id: 1590,
            name: "Latest Recipes",
            slug: "latest-recipes",
            count: 1
        )
        #expect(SearchViewModel.isLatestRecipesCategory(category) == true)
    }

    /// Branch 2 coverage: name match works even if id is not 1590.
    /// This verifies the name fallback path when a category keeps its name but id changes.
    @Test("name match: exact case with non-1590 id")
    func nameMatchWithDifferentId() {
        let category = DODDomain.Category(
            id: 9999,
            name: "Latest Recipes",
            slug: "latest-recipes",
            count: 1
        )
        #expect(SearchViewModel.isLatestRecipesCategory(category) == true)
    }

    /// Case-insensitive test: all lowercase.
    @Test("name match: case-insensitive lowercase")
    func caseInsensitiveLowercase() {
        let category = DODDomain.Category(
            id: 42,
            name: "latest recipes",
            slug: "latest-recipes",
            count: 1
        )
        #expect(SearchViewModel.isLatestRecipesCategory(category) == true)
    }

    /// Case-insensitive test: all uppercase.
    @Test("name match: case-insensitive uppercase")
    func caseInsensitiveUppercase() {
        let category = DODDomain.Category(
            id: 42,
            name: "LATEST RECIPES",
            slug: "latest-recipes",
            count: 1
        )
        #expect(SearchViewModel.isLatestRecipesCategory(category) == true)
    }

    /// Case-insensitive test: mixed case.
    @Test("name match: case-insensitive mixed case")
    func caseInsensitiveMixedCase() {
        let category = DODDomain.Category(
            id: 42,
            name: "LaTeSt ReCiPeS",
            slug: "latest-recipes",
            count: 1
        )
        #expect(SearchViewModel.isLatestRecipesCategory(category) == true)
    }

    /// Negative test: neither id nor name matches.
    @Test("no match: different id and different name")
    func neitherConditionTrue() {
        let category = DODDomain.Category(
            id: 42,
            name: "Desserts",
            slug: "desserts",
            count: 1
        )
        #expect(SearchViewModel.isLatestRecipesCategory(category) == false)
    }

    /// Exact-match guard: singular "Latest Recipe" must NOT match.
    /// Verifies that the match is exact (not a prefix or substring).
    @Test("no match: singular near-miss 'Latest Recipe'")
    func singularNearMissMustNotMatch() {
        let category = DODDomain.Category(
            id: 42,
            name: "Latest Recipe",
            slug: "latest-recipe",
            count: 1
        )
        #expect(SearchViewModel.isLatestRecipesCategory(category) == false)
    }

    /// Exact-match guard: double space "Latest  Recipes" must NOT match.
    /// localizedCaseInsensitiveCompare does NOT normalize whitespace—it only folds
    /// case and applies locale rules. A literal string comparison with double space
    /// differs from single space, so this must be false.
    @Test("no match: whitespace variant 'Latest  Recipes' (double space)")
    func doubleSpaceNearMissMustNotMatch() {
        let category = DODDomain.Category(
            id: 42,
            name: "Latest  Recipes",
            slug: "latest-recipes",
            count: 1
        )
        #expect(SearchViewModel.isLatestRecipesCategory(category) == false)
    }

    /// Combined negative test: both conditions explicitly false with a low id.
    @Test("no match: low id and completely different name")
    func lowIdDifferentNameBothFalse() {
        let category = DODDomain.Category(
            id: 1,
            name: "Appetizers",
            slug: "appetizers",
            count: 1
        )
        #expect(SearchViewModel.isLatestRecipesCategory(category) == false)
    }

    /// Verify disjunction: if either condition is true, result is true.
    /// This test uses a high id (not 1590) with the canonical name.
    @Test("disjunction: name match overrides non-1590 id")
    func disjunctionNameTakePriority() {
        let category = DODDomain.Category(
            id: 5000,
            name: "Latest Recipes",
            slug: "latest-recipes",
            count: 1
        )
        #expect(SearchViewModel.isLatestRecipesCategory(category) == true)
    }
}
