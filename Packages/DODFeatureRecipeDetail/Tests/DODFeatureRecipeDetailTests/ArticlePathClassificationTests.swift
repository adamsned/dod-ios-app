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

    @Test func parsedRecipeWithEmptyInstructionsAndNoCardFallsBackToArticleBody() async throws {
        // DUT-185 (as narrowed by DUT-538): a recipe that parses with EMPTY
        // instructions falls back to the article-body path ONLY when the page
        // ships NO WPRM recipe card. `htmlToReturn` defaults to `<html></html>`
        // (no card), so `hasRecipeCard` is false and the step-less recipe still
        // routes to `.article` — the genuine-article case is preserved.
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 17, withDetail: false)
        dependencies.articleBodyToExtract = "How to Make. Step 1: Open and dump."
        let viewModel = makeViewModel(dependencies: dependencies, listItemID: 17)
        await viewModel.onAppear()
        if case .article(let article) = viewModel.loadState {
            #expect(article.kind == .article)
            #expect(article.articleBodyHTML == "How to Make. Step 1: Open and dump.")
        } else {
            Issue.record("Step-less recipe with no card should fall back to .article, got \(viewModel.loadState)")
        }
    }

    @Test func emptyInstructionsWithWPRMCardStaysRecipeNotArticle() async throws {
        // DUT-538: the 7 Can Soup regression. `parseJSONLD` SUCCEEDS but the
        // recipe has empty instructions (the WPRM card had no instruction rows);
        // however the page ships a `wprm-recipe-container`. Presence of the card
        // means this is a RECIPE — it must NOT be reclassified as an article
        // that dumps the whole blog body. It stays `.ready` with kind `.recipe`.
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 19, withDetail: false)
        dependencies.htmlToReturn = "<html><body><div class=\"wprm-recipe-container\"></div></body></html>"
        dependencies.articleBodyToExtract = "this should not be reached"
        let viewModel = makeViewModel(dependencies: dependencies, listItemID: 19)
        await viewModel.onAppear()
        #expect(viewModel.loadState == .ready)
        #expect(viewModel.recipe?.kind == .recipe)
        #expect(dependencies.markedFailedIDs.isEmpty)
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
