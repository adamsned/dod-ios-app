import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// L1 regression suite locking the pure recipe-vs-article page-classification
/// decision tree in `RecipeDetailViewModel+Classify.swift`
/// (DUT-544 / DUT-577 / DUT-917 bug class).
///
/// Tests drive `classifyPage(html:)` and the static `classifyAsArticle(...)`
/// **directly** through the injected dependency seams — no network, no full
/// `onAppear` fetch cycle — and assert on the returned `PageClassification`
/// enum value, including the `blurbBlocks` carried by `.recipe`.
///
/// Companion to `ArticlePathClassificationTests` (which exercises the same
/// decision tree through the full `onAppear` + `apply(classification:html:)`
/// VM cycle). This suite pins the *return value* of the classification methods
/// themselves, providing finer-grained coverage of every branch.
@MainActor
@Suite("RecipeDetail page classification — classifyPage / classifyAsArticle (DUT-544/577/917)")
struct RecipeDetailPageClassificationTests {

    // MARK: — classifyPage: JSON-LD succeeds → .recipe

    /// [Scenario 1a] JSON-LD parses with non-empty instructions AND the HTML
    /// carries narrative blurb prose (paragraphs before the WPRM card) →
    /// `.recipe` is returned and `blurbBlocks` is populated with at least one
    /// `.paragraph` block. Locks the T-732 / CL-129 blurb-block path on the
    /// classification return value (not on VM state, unlike the blurb tests).
    @Test
    func jsonLDWithInstructionsAndBlurbYieldsRecipeWithBlurbBlocks() async throws {
        let deps = FakeRecipeDetailDependencies()
        deps.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 301, withDetail: true)
        // entry-content with one blurb paragraph before the WPRM card.
        let html = """
            <html><body>
            <div class="entry-content">
            <p>A hearty stew you will love.</p>
            <div class="wprm-recipe-container"><ul><li>1 cup flour</li></ul></div>
            </div>
            </body></html>
            """
        let result = await makeVM(deps: deps, id: 301).classifyPage(html: html)
        guard case .recipe(let recipe, let blurbBlocks) = result else {
            Issue.record("Expected .recipe, got \(result)")
            return
        }
        #expect(recipe.id == 301)
        #expect(!recipe.instructions.isEmpty)
        let paragraphs = blurbBlocks.compactMap { block -> String? in
            if case .paragraph(let text) = block { return String(text.characters) }
            return nil
        }
        #expect(paragraphs.contains { $0.contains("hearty stew") })
    }

    /// [Scenario 1b] JSON-LD parses with non-empty instructions but the HTML
    /// has no `entry-content` blurb region → `.recipe` with `blurbBlocks == []`.
    /// Locks the graceful-fallback contract when blurb extraction returns empty.
    @Test
    func jsonLDWithInstructionsAndNoBlurbYieldsRecipeWithEmptyBlurbBlocks() async throws {
        let deps = FakeRecipeDetailDependencies()
        deps.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 302, withDetail: true)
        // No entry-content wrapper → blurb extractor returns empty → blurbBlocks stays [].
        let html = "<html><body><p>No entry-content wrapper here.</p></body></html>"
        let result = await makeVM(deps: deps, id: 302).classifyPage(html: html)
        guard case .recipe(let recipe, let blurbBlocks) = result else {
            Issue.record("Expected .recipe, got \(result)")
            return
        }
        #expect(recipe.id == 302)
        #expect(blurbBlocks.isEmpty)
    }

    // MARK: — classifyPage: DUT-544 recipe-subject gate

    /// [Scenario 2] JSON-LD parse succeeds but returns EMPTY instructions, and
    /// `hasRecipeJSONLD` returns `true` (the 7-Can-Soup shape: a `@type: Recipe`
    /// subject node exists even though the WPRM card had no instruction rows) →
    /// classification stays `.recipe`, NEVER drops to the article path.
    /// Locks the DUT-44 / DUT-538 regression guard on the classification return value.
    @Test
    func jsonLDWithEmptyInstructionsAndRecipeSubjectStaysRecipe() async throws {
        let deps = FakeRecipeDetailDependencies()
        // withDetail: false → instructions: [], ingredients: []
        deps.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 303, withDetail: false)
        deps.hasRecipeJSONLDResult = true
        let html = "<html><body><div class=\"entry-content\"></div></body></html>"
        let result = await makeVM(deps: deps, id: 303).classifyPage(html: html)
        guard case .recipe(let recipe, _) = result else {
            Issue.record("Empty-instruction recipe subject must stay .recipe, got \(result)")
            return
        }
        #expect(recipe.id == 303)
        // The parse result's empty instruction list is faithfully preserved.
        #expect(recipe.instructions.isEmpty)
    }

    // MARK: — classifyPage: DUT-544 recipe-subject card recovery

    /// [Scenario 3] JSON-LD parse throws (parsedRecipe nil) AND
    /// `hasRecipeJSONLD == true` (genuine recipe page, malformed/thin JSON-LD)
    /// AND a WPRM subject card exists → the article-classify path recovers
    /// `.cardRecipe` with the card's ingredients.
    /// Exercises `classifyPage` end-to-end so the full branch order is covered:
    /// JSON-LD throw → `classifyAsArticle` → `recipeFromWPRMCard`.
    @Test
    func jsonLDFailsWithRecipeSubjectAndWPRMCardYieldsCardRecipe() async throws {
        let deps = FakeRecipeDetailDependencies()
        deps.parsedRecipe = nil  // causes parseJSONLD to throw
        deps.hasRecipeJSONLDResult = true
        let html = """
            <html><body>
            <div class="entry-content">
            <div class="wprm-recipe-container">
            <ul class="wprm-recipe-ingredients">
            <li class="wprm-recipe-ingredient">
              <span class="wprm-recipe-ingredient-name">black beans</span>
            </li>
            </ul>
            </div>
            </div>
            </body></html>
            """
        let result = await makeVM(deps: deps, id: 304).classifyPage(html: html)
        guard case .cardRecipe(let recipe) = result else {
            Issue.record("Recipe-subject card must recover .cardRecipe, got \(result)")
            return
        }
        #expect(recipe.kind == .recipe)
        #expect(recipe.ingredients.contains { $0.text == "black beans" })
    }

    // MARK: — classifyAsArticle: DUT-555 card-only safety net

    /// [Scenario 4] No `@type: Recipe` node (`isRecipeSubject: false`), but a
    /// standalone WPRM card carries BOTH ingredients AND recovered steps →
    /// DUT-555 card-only safety net fires → `.cardRecipe`.
    /// Tested through `classifyAsArticle` directly (static, synchronous seam)
    /// to isolate the DUT-555 both-lists gate from the JSON-LD layer.
    @Test
    func noRecipeSubjectButCardWithBothListsYieldsCardRecipeViaStaticPath() throws {
        let deps = FakeRecipeDetailDependencies()
        let listItem = RecipeDetailTestFixtures.makeListItem(id: 305)
        let url = try #require(URL(string: "https://www.dutchovendaddy.com/r/305/"))
        // Both WPRM ingredient list AND a "How to Make" ordered list present —
        // the stricter card-only gate (DUT-555) requires both lists non-empty.
        let html = """
            <html><body>
            <div class="entry-content">
            <h2 class="wp-block-heading">How to Make It</h2>
            <ol class="is-style-circle-number-list">
              <li>Step 1: Dump every can in the pot.</li>
              <li>Step 2: Simmer for 15 minutes.</li>
            </ol>
            <div class="wprm-recipe-container">
            <ul class="wprm-recipe-ingredients">
              <li class="wprm-recipe-ingredient">
                <span class="wprm-recipe-ingredient-name">black beans</span>
              </li>
              <li class="wprm-recipe-ingredient">
                <span class="wprm-recipe-ingredient-name">sweet corn</span>
              </li>
            </ul>
            </div>
            </div>
            </body></html>
            """
        let result = RecipeDetailViewModel.classifyAsArticle(
            html: html,
            isRecipeSubject: false,
            dependencies: deps,
            listItem: listItem,
            canonicalURL: url
        )
        guard case .cardRecipe(let recipe) = result else {
            Issue.record("Card-only recipe with both lists must yield .cardRecipe, got \(result)")
            return
        }
        #expect(recipe.kind == .recipe)
        #expect(recipe.ingredients.contains { $0.text == "black beans" })
        #expect(!recipe.instructions.isEmpty)
    }

    // MARK: — classifyAsArticle: terminal paths

    /// [Scenario 5] No recipe signal, no usable WPRM card (plain HTML body),
    /// `extractArticleBody` returns a non-empty body → `.article` is returned
    /// with `kind == .article` and `articleBodyHTML` matching the extracted body.
    @Test
    func noRecipeSignalWithArticleBodyYieldsArticle() throws {
        let deps = FakeRecipeDetailDependencies()
        deps.articleBodyToExtract = "<p>The 15 best recipes, ranked.</p>"
        let listItem = RecipeDetailTestFixtures.makeListItem(id: 306)
        let url = try #require(URL(string: "https://www.dutchovendaddy.com/r/306/"))
        let result = RecipeDetailViewModel.classifyAsArticle(
            html: "<html><body><p>plain body text</p></body></html>",
            isRecipeSubject: false,
            dependencies: deps,
            listItem: listItem,
            canonicalURL: url
        )
        guard case .article(let recipe) = result else {
            Issue.record("Non-recipe page with article body must yield .article, got \(result)")
            return
        }
        #expect(recipe.id == 306)
        #expect(recipe.kind == .article)
        #expect(recipe.articleBodyHTML == "<p>The 15 best recipes, ranked.</p>")
    }

    /// [Scenario 6] No recipe signal AND `extractArticleBody` returns empty →
    /// terminal `.unavailable`. Final fallback when both JSON-LD and article-body
    /// extraction failed for a page (DUT-917 terminal guard).
    @Test
    func noRecipeSignalAndEmptyArticleBodyYieldsUnavailable() throws {
        let deps = FakeRecipeDetailDependencies()
        deps.articleBodyToExtract = ""  // default — nothing extractable
        let listItem = RecipeDetailTestFixtures.makeListItem(id: 307)
        let url = try #require(URL(string: "https://www.dutchovendaddy.com/r/307/"))
        let result = RecipeDetailViewModel.classifyAsArticle(
            html: "<html><body></body></html>",
            isRecipeSubject: false,
            dependencies: deps,
            listItem: listItem,
            canonicalURL: url
        )
        guard case .unavailable = result else {
            Issue.record("Empty article body with no recipe signal must yield .unavailable, got \(result)")
            return
        }
    }

    // MARK: — Helper

    private func makeVM(deps: RecipeDetailDependencies, id: Int) -> RecipeDetailViewModel {
        RecipeDetailViewModel(
            listItem: RecipeDetailTestFixtures.makeListItem(id: id),
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/\(id)/")
                ?? URL(filePath: "/"),
            dependencies: deps
        )
    }
}
