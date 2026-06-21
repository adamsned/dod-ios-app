import DODAnalytics
import DODDomain
import DODNetworking
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// L1 unit tests for the article-classification path on
/// ``RecipeDetailViewModel`` (US-37 / CL-63 / AC-37.7 / T-640).
///
/// Pre-T-640 the JSON-LD parse failure always marked the row's blocklist
/// signal and transitioned to `.unavailable`. Post-T-640 the failure is
/// the trigger for article classification:
///
/// 1. JSON-LD succeeds → `.ready` with `recipe.kind == .recipe`.
/// 2. JSON-LD fails + article body extracts → `.article(recipe)` with
///    `recipe.kind == .article`, `recipe.articleBodyHTML` populated.
/// 3. JSON-LD fails + article body empty → `.unavailable` (terminal,
///    blocklist marker stamped per the legacy path).
@MainActor
@Suite("Article classification path (US-37 / CL-63 / T-640)")
struct ArticlePathClassificationTests {

    @Test func jsonLDFailureWithNoArticleBodyMarksBlocklistAndTransitionsToUnavailable() async throws {
        // JSON-LD parse fails AND article body extraction returns empty —
        // terminal `.unavailable` path, same shape pre-T-640.
        let dependencies = FakeRecipeDetailDependencies()
        // fetchHTML succeeds (no `fetchShouldFail`), but `parseJSONLD`
        // throws because `parsedRecipe` is nil. `articleBodyToExtract`
        // defaults to "" so the article branch doesn't fire.
        let viewModel = makeViewModel(dependencies: dependencies, listItemID: 7)
        await viewModel.onAppear()
        #expect(viewModel.loadState == .unavailable)
        #expect(dependencies.markedFailedIDs == [7])
    }

    @Test func jsonLDFailureWithArticleBodyClassifiesAsArticle() async throws {
        // JSON-LD parse fails but article body extracts cleanly — post is
        // classified as `.article` and the view model transitions to
        // `.article(recipe)` with a populated `articleBodyHTML`.
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.articleBodyToExtract = "This is a sanitized article body."
        let viewModel = makeViewModel(dependencies: dependencies, listItemID: 11)
        await viewModel.onAppear()
        if case .article(let article) = viewModel.loadState {
            #expect(article.kind == .article)
            #expect(article.articleBodyHTML == "This is a sanitized article body.")
            #expect(article.id == 11)
        } else {
            Issue.record("Expected .article load state, got \(viewModel.loadState)")
        }
    }

    @Test func successfulJSONLDClassifiesAsRecipeNotArticle() async throws {
        // JSON-LD parse succeeds — recipe path stays the existing `.ready`
        // transition with kind `.recipe`. The article-body extractor is
        // never called even when `articleBodyToExtract` is non-empty.
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 13, withDetail: true)
        dependencies.articleBodyToExtract = "this should not be reached"
        let viewModel = makeViewModel(dependencies: dependencies, listItemID: 13)
        await viewModel.onAppear()
        #expect(viewModel.loadState == .ready)
        #expect(viewModel.recipe?.kind == .recipe)
        #expect(dependencies.markedFailedIDs.isEmpty)
    }

    @Test func parsedRecipeWithEmptyInstructionsFallsBackToArticleBody() async throws {
        // DUT-185: WP Recipe Maker now renders steps client-side and redacts
        // them from the recipe's structured data, so `parseJSONLD` SUCCEEDS but
        // returns a recipe with EMPTY instructions (e.g. Dutch Oven 7 Can Soup).
        // Rather than render a step-less recipe, the view model falls back to
        // the article-body path — where the post's "How to Make" steps live.
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 17, withDetail: false)
        dependencies.articleBodyToExtract = "How to Make. Step 1: Open and dump."
        let viewModel = makeViewModel(dependencies: dependencies, listItemID: 17)
        await viewModel.onAppear()
        if case .article(let article) = viewModel.loadState {
            #expect(article.kind == .article)
            #expect(article.articleBodyHTML == "How to Make. Step 1: Open and dump.")
        } else {
            Issue.record("Step-less recipe should fall back to .article, got \(viewModel.loadState)")
        }
    }

    // MARK: - Helper

    private func makeViewModel(
        dependencies: RecipeDetailDependencies,
        listItemID: Int
    ) -> RecipeDetailViewModel {
        RecipeDetailViewModel(
            listItem: RecipeDetailTestFixtures.makeListItem(id: listItemID),
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/\(listItemID)/") ?? URL(filePath: "/"),
            dependencies: dependencies
        )
    }
}
