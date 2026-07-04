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

    @Test func parsedRecipeWithEmptyInstructionsAndNoRecipeSubjectFallsBackToArticleBody() async throws {
        // DUT-185 (as narrowed by DUT-538, corrected by DUT-544): a page that
        // parses with EMPTY instructions falls back to the article-body path
        // when its subject is NOT a recipe — i.e. no `@type: Recipe` JSON-LD
        // node (`hasRecipeJSONLDResult == false`). `htmlToReturn` defaults to
        // `<html></html>` (no card either), so the step-less post routes to
        // `.article` — the genuine-article case is preserved.
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 17, withDetail: false)
        dependencies.hasRecipeJSONLDResult = false
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

    @Test func emptyInstructionsWithRecipeSubjectStaysRecipeNotArticle() async throws {
        // DUT-538 (as corrected by DUT-544): the 7 Can Soup regression.
        // `parseJSONLD` SUCCEEDS but the recipe has empty instructions (the WPRM
        // card had no instruction rows) and the page's JSON-LD carries a
        // `@type: Recipe` node — a genuine recipe whose subject IS a recipe. It
        // must NOT be reclassified as an article that dumps the whole blog body:
        // it stays `.ready` with kind `.recipe`. (`hasRecipeJSONLDResult`
        // defaults to `true`, modeling the Recipe node the live page carries.)
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

    @Test func roundUpArticleThatEmbedsCardClassifiesAsArticleNotRecipe() async throws {
        // DUT-544: the over-classification bug. The JSON-LD parse FAILS (no
        // Recipe node — the page is a round-up / guide ARTICLE), yet the page
        // embeds a `wprm-recipe-container` card. Pre-DUT-544 the mere card
        // presence forced the recipe path, dumping the card in place of the
        // whole article body. Now the recipe path requires the recipe-SUBJECT
        // signal (`hasRecipeJSONLD == false` here), so the post correctly routes
        // to `.article` and its body is PRESERVED — not replaced by the card.
        let dependencies = FakeRecipeDetailDependencies()
        // parseJSONLD throws (parsedRecipe is nil) — the round-up has no Recipe node.
        dependencies.hasRecipeJSONLDResult = false
        dependencies.htmlToReturn = "<html><body><div class=\"wprm-recipe-container\"></div></body></html>"
        dependencies.articleBodyToExtract = "The 15 best dump cake recipes, ranked. Start with cherry..."
        let viewModel = makeViewModel(dependencies: dependencies, listItemID: 23)
        await viewModel.onAppear()
        if case .article(let article) = viewModel.loadState {
            #expect(article.kind == .article)
            // Body PRESERVED — the whole round-up prose, not the embedded card.
            #expect(article.articleBodyHTML == "The 15 best dump cake recipes, ranked. Start with cherry...")
            #expect(article.id == 23)
        } else {
            Issue.record("Round-up embedding a card should classify as .article, got \(viewModel.loadState)")
        }
    }

    @Test func recipeSubjectWithCardRecoversRecipeWhenJSONLDParseFails() async throws {
        // DUT-544 companion: a GENUINE recipe whose JSON-LD parse fails (thin /
        // malformed Recipe node) but whose page IS recipe-typed
        // (`hasRecipeJSONLD == true`) still routes to the card-recovery recipe
        // path — DUT-538 is preserved for real recipes. The 7 Can Soup shape:
        // card present + recipe subject → `.recipe`, never the article dump.
        let dependencies = FakeRecipeDetailDependencies()
        // parseJSONLD throws (parsedRecipe nil), but the page is recipe-typed...
        dependencies.hasRecipeJSONLDResult = true
        dependencies.htmlToReturn = """
            <html><body>
            <h2>How to Make It</h2>
            <ol class="is-style-circle-number-list"><li>Step 1: Dump every can in.</li></ol>
            <div class="wprm-recipe-container">
            <ul class="wprm-recipe-ingredients">
            <li class="wprm-recipe-ingredient"><span class="wprm-recipe-ingredient-name">black beans</span></li>
            </ul>
            </div>
            </body></html>
            """
        dependencies.articleBodyToExtract = "this should not be reached"
        let viewModel = makeViewModel(dependencies: dependencies, listItemID: 29)
        await viewModel.onAppear()
        #expect(viewModel.loadState == .ready)
        #expect(viewModel.recipe?.kind == .recipe)
        #expect(viewModel.recipe?.ingredients.contains { $0.text == "black beans" } == true)
        #expect(dependencies.markedFailedIDs.isEmpty)
    }

    @Test func cardOnlyRecipeWithNoRecipeNodeRecoversRecipeNotArticle() async throws {
        // DUT-555: a GENUINE recipe whose structured data lives ONLY in the WPRM
        // card — the page has NO `@type: Recipe` JSON-LD node
        // (`hasRecipeJSONLD == false`, older post / schema output disabled). The
        // JSON-LD parse fails, and DUT-544 gated the whole card path on the
        // recipe-subject signal, so this shape dumped as an article. The DUT-555
        // fallback recovers it: the card yields BOTH ingredients AND steps (from
        // the "How to Make" region), so it takes the recipe path.
        let dependencies = FakeRecipeDetailDependencies()
        // parseJSONLD throws (parsedRecipe nil) and the page has no Recipe node.
        dependencies.hasRecipeJSONLDResult = false
        dependencies.htmlToReturn = """
            <html><body>
            <div class="entry-content">
            <h2 class="wp-block-heading">How to Make It</h2>
            <ol class="is-style-circle-number-list"><li>Step 1: Dump every can in.</li></ol>
            <ol class="is-style-circle-number-list"><li>Step 2: Simmer 15 minutes.</li></ol>
            <div class="wprm-recipe-container">
            <ul class="wprm-recipe-ingredients">
            <li class="wprm-recipe-ingredient"><span class="wprm-recipe-ingredient-name">black beans</span></li>
            <li class="wprm-recipe-ingredient"><span class="wprm-recipe-ingredient-name">sweet corn</span></li>
            </ul>
            </div>
            </div>
            </body></html>
            """
        dependencies.articleBodyToExtract = "this should not be reached"
        let viewModel = makeViewModel(dependencies: dependencies, listItemID: 31)
        await viewModel.onAppear()
        #expect(viewModel.loadState == .ready)
        #expect(viewModel.recipe?.kind == .recipe)
        #expect(viewModel.recipe?.ingredients.contains { $0.text == "black beans" } == true)
        #expect(viewModel.recipe?.instructions.isEmpty == false)
        #expect(dependencies.markedFailedIDs.isEmpty)
    }

    @Test func roundUpWithEmbeddedCardLackingBothListsStillClassifiesAsArticle() async throws {
        // DUT-555 must not re-break DUT-544: a round-up ARTICLE (no Recipe node)
        // that embeds a WPRM card which does NOT carry BOTH a full ingredient
        // list AND recovered steps as the page subject — here the card has
        // ingredients but no steps (no "How to Make" region / instruction rows) —
        // stays on the article-body path with its prose PRESERVED.
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.hasRecipeJSONLDResult = false
        dependencies.htmlToReturn = """
            <html><body>
            <div class="entry-content">
            <p>The 15 best dump cake recipes, ranked.</p>
            <div class="wprm-recipe-container">
            <ul class="wprm-recipe-ingredients">
            <li class="wprm-recipe-ingredient"><span class="wprm-recipe-ingredient-name">cherry pie filling</span></li>
            </ul>
            </div>
            </div>
            </body></html>
            """
        dependencies.articleBodyToExtract = "The 15 best dump cake recipes, ranked. Start with cherry..."
        let viewModel = makeViewModel(dependencies: dependencies, listItemID: 37)
        await viewModel.onAppear()
        if case .article(let article) = viewModel.loadState {
            #expect(article.kind == .article)
            #expect(article.articleBodyHTML == "The 15 best dump cake recipes, ranked. Start with cherry...")
            #expect(article.id == 37)
        } else {
            Issue.record("Round-up whose card lacks both lists should stay .article, got \(viewModel.loadState)")
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
