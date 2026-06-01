import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// L1 view-model coverage for the T-736 / CL-133 / AC-4.12 cache-hit
/// background blurb-refresh path. Pre-T-736, `viewModel.blurbBlocks` was
/// view-local state that only populated via the fresh-fetch path
/// (`RecipeDetailViewModel+Fetch.fetchAndParse()` line 47-51); the cache-hit
/// fast path in `onAppear()` returned via `loadState = .ready` WITHOUT
/// touching it, so every re-open of a previously-cached recipe rendered
/// the empty-`blurbBlocks` fallback (`Text(strippedExcerpt)` per
/// `RecipeDetailView+Blurb.swift` lines 124-134) instead of the rich
/// `ArticleBlocksView` path. T-736 / CL-133 closes the gap with a
/// `refreshBlurbBlocks(forCanonicalURL:)` private helper that the cache-hit
/// `.recipe` branch fires-and-forgets after `loadState = .ready`. The
/// helper is gated on `isOnline()`, `try?`s the HTML fetch (fail-silent on
/// transient errors), and assigns `blurbBlocks` only when the parsed
/// result is non-empty (guard against transient-parse-failure downgrade).
///
/// Spec trace: AC-4.12 (amended), CL-133, REG-33.
@MainActor
@Suite("RecipeDetailViewModel.refreshBlurbBlocks (T-736 / CL-133)")
struct RecipeDetailViewModelBlurbRefreshTests {

    /// Happy path: cache-hit + online + fetch returns known-good HTML →
    /// `blurbBlocks` populated after `onAppear()` completes. The view's
    /// `@Observable` binding re-renders the blurb surface from the
    /// fallback `Text` path to the rich `ArticleBlocksView` path with
    /// the "..." + More affordance.
    @Test func cacheHitWithOnlineDependencyPopulatesBlurbBlocksFromBackgroundFetch() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.online = true
        dependencies.cachedRecipes[300] = RecipeDetailTestFixtures.makeRecipe(
            id: 300,
            withDetail: true
        )
        dependencies.htmlToReturn = """
            <html><body>
            <div class="entry-content">
            <p>A refreshed blurb paragraph from the cache-hit refresh path.</p>
            <p>A second blurb paragraph.</p>
            <div class="wprm-recipe-container">
            <ul><li>1 cup flour</li></ul>
            </div>
            </div>
            </body></html>
            """
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 300)

        await viewModel.onAppear()

        #expect(viewModel.loadState == .ready)
        // The background refresh fetched the HTML and populated blurbBlocks.
        #expect(dependencies.fetchCount == 1)
        #expect(!viewModel.blurbBlocks.isEmpty)
        // Recipe-card structured content must NOT leak into the blurb.
        let allParagraphText = viewModel.blurbBlocks.compactMap { block -> String? in
            if case .paragraph(let text) = block { return String(text.characters) }
            return nil
        }
        #expect(allParagraphText.contains { $0.contains("refreshed blurb paragraph") })
        #expect(!allParagraphText.contains { $0.contains("1 cup flour") })
    }

    /// Cache-hit + offline: the background refresh skips the network call
    /// entirely (gated on `dependencies.isOnline()`). `blurbBlocks` stays
    /// empty and the view renders the collapsed-only fallback. Issuing a
    /// network call we know will fail wastes battery + adds spurious
    /// error-log noise; skipping is the correct behavior.
    @Test func cacheHitWithOfflineDependencySkipsRefreshAndLeavesBlurbBlocksEmpty() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.online = false
        dependencies.cachedRecipes[301] = RecipeDetailTestFixtures.makeRecipe(
            id: 301,
            withDetail: true
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 301)

        await viewModel.onAppear()

        #expect(viewModel.loadState == .ready)
        // Offline: the refresh never issued a fetch.
        #expect(dependencies.fetchCount == 0)
        #expect(viewModel.blurbBlocks.isEmpty)
    }

    /// Cache-hit + online + fetch throws: the refresh fail-silents on
    /// transient network errors (the cached view is already on screen, a
    /// snackbar would feel like the app is broken in a context where it
    /// manifestly is not). `blurbBlocks` stays empty AND no error surfaces
    /// to the user. The next online open re-attempts. Matches the
    /// `loadRatingsAndComments` no-op-on-failure pattern (REG-14 / AC-14.6).
    @Test func cacheHitWithFetchErrorLeavesBlurbBlocksEmptyAndDoesNotSurfaceError() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.online = true
        dependencies.fetchShouldFail = true
        dependencies.cachedRecipes[302] = RecipeDetailTestFixtures.makeRecipe(
            id: 302,
            withDetail: true
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 302)

        await viewModel.onAppear()

        #expect(viewModel.loadState == .ready)
        // The fetch was attempted but threw → fail-silent → no blurb update.
        #expect(dependencies.fetchCount == 1)
        #expect(viewModel.blurbBlocks.isEmpty)
        // Background-refresh failures must NOT trigger a user-visible
        // snackbar — the cached view is already a valid render.
        #expect(viewModel.snackbarMessage == nil)
    }

    /// Cache-hit + online + fetch returns HTML that produces an empty parse
    /// result (e.g. no `entry-content` div, or zero `<p>` blocks before the
    /// recipe card): the non-empty guard prevents the empty result from
    /// overwriting a previously-set value. The view-model lives for the
    /// duration of the `RecipeDetailView`; a previous successful refresh's
    /// `blurbBlocks` survives the new transient parse failure. Without
    /// the guard, the view would downgrade from rich-blurb to fallback-
    /// `Text` on a transient subsequent refresh.
    @Test func cacheHitWithEmptyParseResultDoesNotOverwritePreviousNonEmptyValue() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.online = true
        dependencies.cachedRecipes[303] = RecipeDetailTestFixtures.makeRecipe(
            id: 303,
            withDetail: true
        )
        // The HTML the refresh fetches has NO entry-content wrapper, so
        // the extractor returns empty and the parser produces no blocks.
        dependencies.htmlToReturn = "<html><body><p>No entry content wrapper here.</p></body></html>"
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 303)
        // Seed a previously-successful population that the refresh should
        // NOT downgrade.
        let seeded: [ArticleBlock] = [
            .paragraph(AttributedString("a previously-fetched paragraph"))
        ]
        viewModel.blurbBlocks = seeded

        await viewModel.onAppear()

        #expect(viewModel.loadState == .ready)
        // The fetch was attempted and produced empty extract → the guard
        // preserved the seeded population.
        #expect(dependencies.fetchCount == 1)
        #expect(viewModel.blurbBlocks.count == 1)
        if case .paragraph(let text) = viewModel.blurbBlocks[0] {
            #expect(String(text.characters) == "a previously-fetched paragraph")
        } else {
            Issue.record("expected the seeded paragraph to survive the empty-parse refresh")
        }
    }

    /// Sanity: the cache-miss path (no `cachedRecipes` entry, or cached
    /// recipe with `hasDetail == false`) still routes through the existing
    /// `fetchAndParse` flow which populates `blurbBlocks` directly — T-736
    /// only adds behavior on the cache-hit branch and is non-regressing
    /// for fresh-fetch paths.
    @Test func cacheMissPathStillPopulatesBlurbBlocksViaFetchAndParse() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.online = true
        // No cachedRecipes entry → cache miss → fetchAndParse runs.
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(
            id: 304,
            withDetail: true
        )
        dependencies.htmlToReturn = """
            <html><body>
            <div class="entry-content">
            <p>Fresh-fetch blurb paragraph.</p>
            <div class="wprm-recipe-container"><p>card</p></div>
            </div>
            </body></html>
            """
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 304)

        await viewModel.onAppear()

        #expect(viewModel.loadState == .ready)
        // Fresh-fetch path issues exactly one HTML fetch (no double-fetch
        // from a redundant refresh on top of fetchAndParse).
        #expect(dependencies.fetchCount == 1)
        #expect(!viewModel.blurbBlocks.isEmpty)
    }

    // MARK: - Helpers

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
