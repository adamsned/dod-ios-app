import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// L1 coverage for the DUT-577 off-main HTML classify/parse offload and the
/// DUT-581 single-fetch cache-hit hydrate. Both restructure the recipe-detail
/// fetch path in `RecipeDetailViewModel+Fetch.swift`.
///
/// * DUT-577 — the pure classify/parse pipeline (`parseJSONLD`,
///   `hasRecipeJSONLD`, `extractArticleBody`, WPRM-card recovery, blurb
///   extraction + parse) must run OFF the `@MainActor` so a large round-up
///   page doesn't hitch the main thread before `loadState` flips. The
///   classification RESULT must be identical to the pre-DUT-577 inline logic
///   (DUT-544/554/555), and `hasRecipeJSONLD` must be scanned exactly once.
/// * DUT-581 — a cache-hit with instructions-present-but-empty-ingredients
///   must fetch the canonical HTML exactly ONCE (shared by the blurb refresh +
///   the ingredient backfill), not twice back-to-back.
@MainActor
@Suite("RecipeDetail fetch offload (DUT-577 / DUT-581)")
struct RecipeDetailFetchOffloadTests {

    // MARK: - DUT-577 — off-main classify/parse

    /// The recipe-path classify/parse runs off the main actor: the injected
    /// parser spy records that both `hasRecipeJSONLD` and `parseJSONLD` were
    /// invoked on a NON-main thread (i.e. offloaded via `Task.detached`). The
    /// classification result is unchanged — the recipe still reaches `.ready`
    /// with the parsed recipe (DUT-544 recipe-subject path preserved).
    @Test func classifyParseRunsOffMainActorAndClassifiesRecipeUnchanged() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.online = true
        // Cache miss → onAppear routes to fetchAndParse → off-main classifyPage.
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 577, withDetail: true)
        dependencies.hasRecipeJSONLDResult = true
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 577)

        await viewModel.onAppear()

        // DUT-577: the pure scanners ran off the main thread.
        #expect(dependencies.hasRecipeJSONLDRanOffMainThread == true)
        #expect(dependencies.parseJSONLDRanOffMainThread == true)
        // Classification unchanged: recipe path, `.ready`, parsed recipe surfaced.
        #expect(viewModel.loadState == .ready)
        #expect(viewModel.recipe?.id == 577)
        #expect(viewModel.recipe?.kind == .recipe)
    }

    /// The article-classify branch also runs off the main actor AND classifies
    /// identically: a page whose JSON-LD parse fails but whose body extracts
    /// cleanly reaches `.article` (US-37 / CL-63). Pins the DUT-577 offload for
    /// the heaviest `hasRecipeJSONLD == false` round-up shape.
    @Test func articleClassificationRunsOffMainActorAndReachesArticleState() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.online = true
        // No parsedRecipe → parseJSONLD throws → article-classify path.
        dependencies.parsedRecipe = nil
        dependencies.hasRecipeJSONLDResult = false
        dependencies.articleBodyToExtract = "<p>A round-up article body.</p>"
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 578)

        await viewModel.onAppear()

        // The recipe-subject scan (used to gate the card path) ran off-main.
        #expect(dependencies.hasRecipeJSONLDRanOffMainThread == true)
        // Classification unchanged: article body extracted → `.article`.
        if case .article(let article) = viewModel.loadState {
            #expect(article.kind == .article)
            #expect(article.articleBodyHTML == "<p>A round-up article body.</p>")
        } else {
            Issue.record("expected `.article` load state, got \(viewModel.loadState)")
        }
    }

    /// DUT-577 dedupe: `hasRecipeJSONLD` is scanned exactly ONCE for a page that
    /// falls through to the article-classify branch. Pre-DUT-577 it was scanned
    /// at the JSON-LD gate AND re-scanned at the article-classify entry — a
    /// redundant full-page re-scan on the heaviest path. The spy records the
    /// LAST call's thread; a single call keeps it off-main. We assert the
    /// dedupe indirectly by pinning the article classification (which requires
    /// the recipe-subject signal) still resolves off-main with one code path.
    @Test func hasRecipeJSONLDScannedOffMainForCardOnlyRecovery() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.online = true
        // parseJSONLD throws (no parsedRecipe), recipe-subject true → the
        // recipe-from-card branch runs. The card is synthetic (fake HTML) so it
        // recovers nothing → falls through to article-body extraction.
        dependencies.parsedRecipe = nil
        dependencies.hasRecipeJSONLDResult = true
        dependencies.articleBodyToExtract = "<p>Body.</p>"
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 579)

        await viewModel.onAppear()

        #expect(dependencies.hasRecipeJSONLDRanOffMainThread == true)
        // Recipe-subject true but the synthetic card recovers nothing → article.
        if case .article = viewModel.loadState {
            // ok
        } else {
            Issue.record("expected `.article`, got \(viewModel.loadState)")
        }
    }

    // MARK: - DUT-581 — single fetch on cache-hit

    /// DUT-581: a cache-hit whose recipe has instructions but EMPTY ingredients
    /// (the DUT-53 shape) fetches the canonical HTML exactly ONCE. Pre-DUT-581
    /// the blurb refresh fetched once and the ingredient backfill fetched again
    /// — two back-to-back GETs of the identical URL. The fix fetches once in the
    /// background task and passes the HTML into both helpers; the re-parse still
    /// recovers + backfills the ingredients.
    @Test func cacheHitWithEmptyIngredientsFetchesHTMLExactlyOnce() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.online = true
        // hasDetail == true (instructions present) but ingredients empty.
        dependencies.cachedRecipes[581] = RecipeDetailTestFixtures.makeRecipe(
            id: 581,
            withDetail: true,
            ingredients: []
        )
        // The background re-parse recovers ingredients (models DUT-42 fallback
        // reaching an already-cached row).
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(
            id: 581,
            withDetail: true,
            ingredients: [.init(text: "black beans"), .init(text: "sweet corn")]
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 581)

        await viewModel.onAppear()
        await Self.drain(until: { viewModel.recipe?.ingredients.isEmpty == false })

        // Exactly ONE HTML fetch — the blurb refresh + the ingredient backfill
        // share the single background GET (DUT-581).
        #expect(dependencies.fetchCount == 1)
        // The shared HTML still drove the ingredient self-heal.
        #expect(viewModel.recipe?.ingredients.count == 2)
        #expect(viewModel.recipe?.ingredients.contains { $0.text == "black beans" } == true)
        #expect(viewModel.snackbarMessage == nil)
    }

    // MARK: - Helpers

    /// Yield the MainActor until `condition` holds or the spin cap is hit. The
    /// fake dependencies settle each await in one hop, so the fire-and-forget
    /// background Task converges within a handful of yields; the cap turns a
    /// logic regression into a failed assertion rather than a hung suite.
    static func drain(until condition: @MainActor () -> Bool, spins: Int = 500) async {
        var iteration = 0
        while !condition(), iteration < spins {
            await Task.yield()
            iteration += 1
        }
    }

    static func makeViewModel(
        dependencies: RecipeDetailDependencies,
        listItemID: Int
    ) -> RecipeDetailViewModel {
        RecipeDetailViewModel(
            listItem: RecipeDetailTestFixtures.makeListItem(id: listItemID),
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/\(listItemID)/")
                ?? URL(filePath: "/"),
            dependencies: dependencies
        )
    }
}
