import DODDomain
import Testing

@testable import DODFeatureRecipeDetail

/// Regression coverage for `loadRelated`'s self-exclusion + count-cap
/// interaction: the current recipe can appear in its own category's
/// "related" listing (recency-sorted, small categories especially), and
/// `relatedRecipes` deliberately over-fetches by one so filtering the
/// self-match out still leaves a full 4 to show. Before this fix,
/// `relatedRecipes` truncated to 4 BEFORE the caller's self-exclusion
/// filter ran, so a self-match inside the first 4 silently dropped the
/// strip to 3 with no way to backfill from the (already-discarded) 5th
/// fetched item.
@MainActor
@Suite("RecipeDetailViewModel.loadRelated self-exclusion (AC-4.6)")
struct RecipeDetailLoadRelatedTests {

    @Test func selfMatchWithinFirstFourStillYieldsFourRelated() async {
        let dependencies = FakeRecipeDetailDependencies()
        // 5 fetched items — the CURRENT recipe (id: 1) is among the first 4,
        // so a naive fetch-4-then-filter would only leave 3.
        dependencies.related = [
            RecipeDetailTestFixtures.makeListItem(id: 1),  // the recipe being viewed
            RecipeDetailTestFixtures.makeListItem(id: 2),
            RecipeDetailTestFixtures.makeListItem(id: 3),
            RecipeDetailTestFixtures.makeListItem(id: 4),
            RecipeDetailTestFixtures.makeListItem(id: 5),
        ]
        let viewModel = RecipeDetailViewModelTests.makeViewModel(dependencies: dependencies, listItemID: 1)

        await viewModel.loadRelated(forCategoryID: 336)

        #expect(viewModel.related.count == 4)
        #expect(viewModel.related.map(\.id) == [2, 3, 4, 5])
    }

    @Test func noSelfMatchKeepsTheFirstFourInOrder() async {
        let dependencies = FakeRecipeDetailDependencies()
        // The current recipe (id: 1) isn't in the fetched set at all — the
        // ordinary case. The strip caps at 4 even though 5 were fetched.
        dependencies.related = [
            RecipeDetailTestFixtures.makeListItem(id: 2),
            RecipeDetailTestFixtures.makeListItem(id: 3),
            RecipeDetailTestFixtures.makeListItem(id: 4),
            RecipeDetailTestFixtures.makeListItem(id: 5),
            RecipeDetailTestFixtures.makeListItem(id: 6),
        ]
        let viewModel = RecipeDetailViewModelTests.makeViewModel(dependencies: dependencies, listItemID: 1)

        await viewModel.loadRelated(forCategoryID: 336)

        #expect(viewModel.related.count == 4)
        #expect(viewModel.related.map(\.id) == [2, 3, 4, 5])
    }

    @Test func offlineClearsRelatedWithoutFetching() async {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.online = false
        dependencies.related = [RecipeDetailTestFixtures.makeListItem(id: 2)]
        let viewModel = RecipeDetailViewModelTests.makeViewModel(dependencies: dependencies, listItemID: 1)

        await viewModel.loadRelated(forCategoryID: 336)

        #expect(viewModel.related.isEmpty)
    }

    @Test func nilCategoryIDClearsRelatedWithoutFetching() async {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.related = [RecipeDetailTestFixtures.makeListItem(id: 2)]
        let viewModel = RecipeDetailViewModelTests.makeViewModel(dependencies: dependencies, listItemID: 1)

        await viewModel.loadRelated(forCategoryID: nil)

        #expect(viewModel.related.isEmpty)
    }
}
