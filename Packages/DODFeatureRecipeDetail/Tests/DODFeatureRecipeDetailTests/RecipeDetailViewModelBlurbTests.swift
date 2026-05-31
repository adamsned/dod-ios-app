import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// L1 view-model coverage for the T-732 / CL-129 / AC-4.12 `blurbBlocks`
/// property — verifies the fetch path populates the rich `[ArticleBlock]`
/// array from the recipe page HTML, and that extraction failure leaves
/// `blurbBlocks` empty so the view falls back to the collapsed-only state.
///
/// Spec trace: AC-4.12, CL-129, REG-33.
@MainActor
@Suite("RecipeDetailViewModel.blurbBlocks (T-732 / CL-129)")
struct RecipeDetailViewModelBlurbTests {

    /// Happy path: the fetched HTML contains an `entry-content` div with
    /// narrative blurb prose before the WPRM recipe card. The view model
    /// extracts + parses the blurb into `[ArticleBlock]`s on the fetch
    /// path's success branch.
    @Test func blurbBlocksPopulatedFromFreshFetchWithWPRMCard() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(
            id: 200,
            withDetail: true
        )
        dependencies.htmlToReturn = """
            <html><body>
            <div class="entry-content">
            <p>This is the blurb above the recipe card.</p>
            <p>A second blurb paragraph.</p>
            <div class="wprm-recipe-container">
            <ul><li>1 cup flour</li></ul>
            </div>
            </div>
            </body></html>
            """
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 200)
        await viewModel.onAppear()

        #expect(viewModel.loadState == .ready)
        // Expect two paragraph blocks from the two `<p>` tags before the card.
        #expect(viewModel.blurbBlocks.count == 2)
        // Recipe-card structured content must NOT leak into the blurb.
        let allParagraphText = viewModel.blurbBlocks.compactMap { block -> String? in
            if case .paragraph(let text) = block { return String(text.characters) }
            return nil
        }
        #expect(allParagraphText.contains { $0.contains("blurb above the recipe card") })
        #expect(allParagraphText.contains { $0.contains("second blurb paragraph") })
        #expect(!allParagraphText.contains { $0.contains("1 cup flour") })
    }

    /// HTML present but `entry-content` slice missing entirely — extraction
    /// returns empty string → parser returns `[]` → `blurbBlocks` stays at
    /// its `[]` default. The view falls back to collapsed-only.
    @Test func blurbBlocksEmptyWhenExtractionReturnsNothing() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(
            id: 201,
            withDetail: true
        )
        // No entry-content wrapper anywhere — extractor returns empty.
        dependencies.htmlToReturn = "<html><body><p>No entry content here.</p></body></html>"
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 201)
        await viewModel.onAppear()

        #expect(viewModel.loadState == .ready)
        #expect(viewModel.blurbBlocks.isEmpty)
    }

    /// Cached-recipe path skips the network fetch — `blurbBlocks` stays at
    /// its empty default until the next online open repopulates via the
    /// fresh-fetch path. The view falls back to collapsed-only gracefully.
    @Test func blurbBlocksEmptyOnCachedRecipePath() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.cachedRecipes[202] = RecipeDetailTestFixtures.makeRecipe(
            id: 202,
            withDetail: true
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 202)
        await viewModel.onAppear()

        #expect(viewModel.loadState == .ready)
        // Cache hit means fetchHTML was never called → no HTML to extract from
        // → blurbBlocks is empty (the graceful-fallback contract).
        #expect(dependencies.fetchCount == 0)
        #expect(viewModel.blurbBlocks.isEmpty)
    }

    /// Defensive: a recipe page without a WPRM card (custom theme / non-
    /// WPRM page) falls back to the full `entry-content` slice. The blurb
    /// extractor preserves the prose so the view has something to render
    /// when expanded.
    @Test func blurbBlocksPopulatedWhenNoWPRMCardPresent() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(
            id: 203,
            withDetail: true
        )
        dependencies.htmlToReturn = """
            <html><body>
            <div class="entry-content">
            <p>Blurb without a recipe card.</p>
            </div>
            </body></html>
            """
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 203)
        await viewModel.onAppear()

        #expect(viewModel.loadState == .ready)
        #expect(viewModel.blurbBlocks.count == 1)
    }

    // MARK: - hasExpandableBlurb (T-733 / CL-130)

    /// `hasExpandableBlurb` returns true when `blurbBlocks` contains at
    /// least one `.paragraph` block — the broadened-but-narrower More/Less
    /// visibility gate per CL-130.
    @Test func hasExpandableBlurbTrueWhenParagraphPresent() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(
            id: 230,
            withDetail: true
        )
        dependencies.htmlToReturn = """
            <html><body>
            <div class="entry-content">
            <p>A blurb paragraph.</p>
            <div class="wprm-recipe-container"><p>card</p></div>
            </div>
            </body></html>
            """
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 230)
        await viewModel.onAppear()

        #expect(viewModel.hasExpandableBlurb)
    }

    /// `hasExpandableBlurb` returns false when `blurbBlocks` is empty —
    /// no extraction succeeded, no expansion content.
    @Test func hasExpandableBlurbFalseWhenBlocksEmpty() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(
            id: 231,
            withDetail: true
        )
        // No entry-content wrapper → extractor returns empty → no blocks.
        dependencies.htmlToReturn = "<html><body><p>No entry content.</p></body></html>"
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 231)
        await viewModel.onAppear()

        #expect(viewModel.blurbBlocks.isEmpty)
        #expect(!viewModel.hasExpandableBlurb)
    }

    /// `hasExpandableBlurb` returns false when `blurbBlocks` contains only
    /// non-paragraph blocks (heading, image, list). Pre-CL-130 the
    /// `!isEmpty` gate would have surfaced a More button here with nothing
    /// meaningful behind it; the broadened-but-narrower `.paragraph`-only
    /// gate correctly hides it. Constructed by direct assignment to keep
    /// the test independent of the HTML fixture path.
    @Test func hasExpandableBlurbFalseWhenOnlyNonParagraphBlocks() throws {
        let dependencies = FakeRecipeDetailDependencies()
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 232)
        let imageURL = try #require(URL(string: "https://example.com/x.png"))
        viewModel.blurbBlocks = [
            .heading(level: 2, text: AttributedString("A heading")),
            .image(url: imageURL, caption: nil),
            .list(ordered: false, items: [AttributedString("item")]),
        ]

        #expect(!viewModel.hasExpandableBlurb)
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
