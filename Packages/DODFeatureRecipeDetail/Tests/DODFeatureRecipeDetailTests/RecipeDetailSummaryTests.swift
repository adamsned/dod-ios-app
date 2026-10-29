import DODDomain
import DODIntelligence
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// L1 coverage for the US-54 / T-932 (AC-54.2) on-device "Summarize" seam on
/// recipe / article detail. Mirrors the Shopping List substitution tests: a
/// deterministic ``FakeIntelligenceService`` drives the availability gate and
/// the `.idle → .loading → .loaded / .notFound` state machine without touching
/// FoundationModels.
@MainActor
@Suite("Recipe Detail — Summarize (T-932 / US-54)")
struct RecipeDetailSummaryTests {

    /// Available service + a canned summary → the state machine reaches
    /// `.loaded` carrying that text.
    @Test func availableServiceReachesLoaded() async {
        let vm = Self.makeViewModel(
            intelligence: FakeIntelligenceService(isAvailable: true, summary: "A short summary.")
        )
        #expect(vm.isSummaryAvailable)

        await vm.requestSummary()

        #expect(vm.summary == .loaded(text: "A short summary."))
    }

    /// Unavailable service → the affordance is unavailable AND `requestSummary()`
    /// is a no-op (the state never leaves `.idle`), so no empty sheet can open on
    /// an unsupported device.
    @Test func unavailableServiceHidesAffordanceAndRequestIsNoOp() async {
        let vm = Self.makeViewModel(
            intelligence: FakeIntelligenceService(isAvailable: false)
        )
        #expect(vm.isSummaryAvailable == false)

        await vm.requestSummary()

        #expect(vm.summary == .idle)
    }

    /// A `nil` result from an AVAILABLE service (empty body / model error /
    /// guardrail rejection) → the graceful `.notFound` state.
    @Test func nilSummaryReachesNotFound() async {
        let vm = Self.makeViewModel(
            intelligence: FakeIntelligenceService(isAvailable: true, summary: nil)
        )

        await vm.requestSummary()

        #expect(vm.summary == .notFound)
    }

    /// No service wired at all → the affordance is hidden and requests no-op.
    @Test func noServiceHidesAffordance() async {
        let vm = Self.makeViewModel(intelligence: nil)
        #expect(vm.isSummaryAvailable == false)

        await vm.requestSummary()

        #expect(vm.summary == .idle)
    }

    /// `dismissSummary()` returns the state to `.idle` (which dismisses the
    /// sheet through its `isPresented` binding).
    @Test func dismissReturnsToIdle() async {
        let vm = Self.makeViewModel(
            intelligence: FakeIntelligenceService(isAvailable: true, summary: "x")
        )
        await vm.requestSummary()
        #expect(vm.summary == .loaded(text: "x"))

        vm.dismissSummary()
        #expect(vm.summary == .idle)
    }

    /// Body-text source — an article strips its cached `articleBodyHTML` to
    /// plain text for the model (no new fetch).
    @Test func summaryBodyTextForArticleStripsHTML() {
        let vm = Self.makeViewModel(intelligence: nil)
        let article = Recipe(
            id: 7,
            slug: "roundup",
            title: "Best Dutch Oven Recipes",
            excerpt: "Excerpt.",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/roundup/") ?? URL(filePath: "/"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            kind: .article,
            articleBodyHTML: "<p>Hello <b>world</b>.</p>"
        )
        vm.loadState = .article(article)

        #expect(vm.summaryBodyText == "Hello world.")
    }

    /// Body-text source — a recipe with no parsed blurb falls back to the
    /// recipe excerpt.
    @Test func summaryBodyTextForRecipeFallsBackToExcerpt() {
        let vm = Self.makeViewModel(intelligence: nil)
        vm.recipe = RecipeDetailTestFixtures.makeRecipe(id: 1, withDetail: true)

        #expect(vm.summaryBodyText == "Tasty.")
    }

    // MARK: - Fixtures

    static func makeViewModel(
        intelligence: (any DODIntelligenceService)?
    ) -> RecipeDetailViewModel {
        let vm = RecipeDetailViewModel(
            listItem: RecipeDetailTestFixtures.makeListItem(id: 1),
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/1/") ?? URL(filePath: "/"),
            dependencies: FakeRecipeDetailDependencies(),
            intelligence: intelligence
        )
        vm.recipe = RecipeDetailTestFixtures.makeRecipe(id: 1, withDetail: true)
        return vm
    }
}
