import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureFeed

/// DUT-571 — coverage for the top-of-feed First-Cookout hero card's gating +
/// rung-seeding logic. The card is surfaced (previously dead code) so a brand-new
/// cook lands on the guided "one guaranteed win" front door the tour promises.
///
/// The show/hide decision (`FeedView.shouldShowFirstCookoutHero`) and the
/// rung-seed (`GuidedCookout.nextUncookedRung`, driven off the same
/// `FeedViewModel.cookLogs()` seam the hero's `.task` loads) are pure/testable
/// without a SwiftUI host, mirroring `CookChooserFlowTests`.
@MainActor
@Suite("Feed First-Cookout hero (DUT-571)")
struct FeedFirstCookoutHeroTests {

    // MARK: - Gating: shouldShowFirstCookoutHero

    @Test func newCookSeesHeroSeededToFirstRung() async {
        // A brand-new cook: empty cook log, not dismissed. The hero must show,
        // seeded to the first rung ("Your First Cookout").
        let dependencies = FakeFeedDependencies()  // no cooks
        let viewModel = FeedViewModel(dependencies: dependencies)
        let nextRung = GuidedCookout.nextUncookedRung(
            cookedRecipeIDs: Set((await viewModel.cookLogs()).map(\.recipeID))
        )
        #expect(nextRung == GuidedCookout.path.first)
        #expect(nextRung?.isFirstRung == true)
        #expect(
            FeedView.shouldShowFirstCookoutHero(
                cookStateLoaded: true,
                nextRung: nextRung,
                dismissed: false
            )
        )
    }

    @Test func dismissedCookHidesHero() {
        // Even a new cook (a real next rung) must NOT see the card once dismissed.
        #expect(
            FeedView.shouldShowFirstCookoutHero(
                cookStateLoaded: true,
                nextRung: GuidedCookout.path.first,
                dismissed: true
            ) == false
        )
    }

    @Test func graduatedCookHidesHero() async {
        // A cook who has logged every rung has no next un-cooked rung → hidden.
        let dependencies = FakeFeedDependencies()
        dependencies.cooks = GuidedCookout.path.map(Self.cook(rung:))
        let viewModel = FeedViewModel(dependencies: dependencies)
        let nextRung = GuidedCookout.nextUncookedRung(
            cookedRecipeIDs: Set((await viewModel.cookLogs()).map(\.recipeID))
        )
        #expect(nextRung == nil)
        #expect(
            FeedView.shouldShowFirstCookoutHero(
                cookStateLoaded: true,
                nextRung: nextRung,
                dismissed: false
            ) == false
        )
    }

    @Test func returningCookSeesHeroSeededToNextRung() async {
        // One rung logged → the hero shows, seeded to the SECOND rung ("Your Next
        // Cookout"), not a stale rung 1.
        let dependencies = FakeFeedDependencies()
        dependencies.cooks = [Self.cook(rung: GuidedCookout.path[0])]
        let viewModel = FeedViewModel(dependencies: dependencies)
        let nextRung = GuidedCookout.nextUncookedRung(
            cookedRecipeIDs: Set((await viewModel.cookLogs()).map(\.recipeID))
        )
        #expect(nextRung == GuidedCookout.path[1])
        #expect(nextRung?.isFirstRung == false)
        #expect(
            FeedView.shouldShowFirstCookoutHero(
                cookStateLoaded: true,
                nextRung: nextRung,
                dismissed: false
            )
        )
    }

    @Test func heroHiddenUntilCookStateLoads() {
        // Before the `.task` loads the real cook state, the hero must not flash a
        // stale rung 1 — the loaded gate keeps it hidden even for a would-be new cook.
        #expect(
            FeedView.shouldShowFirstCookoutHero(
                cookStateLoaded: false,
                nextRung: GuidedCookout.path.first,
                dismissed: false
            ) == false
        )
    }

    // MARK: - Dismissal persistence

    @Test func dismissalPersistsThroughAppStorageKey() {
        // The card's "x" flips the `@AppStorage` boolean; the gating function then
        // reads it back as dismissed. Assert the key round-trips through the same
        // `.standard` store the view binds to (mirrors the layout-toggle key).
        let key = FeedView.firstCookoutHeroDismissedKey
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: key)
        defer { defaults.removeObject(forKey: key) }

        #expect(defaults.bool(forKey: key) == false)
        // Simulate the onDismiss write.
        defaults.set(true, forKey: key)
        #expect(defaults.bool(forKey: key))
        #expect(
            FeedView.shouldShowFirstCookoutHero(
                cookStateLoaded: true,
                nextRung: GuidedCookout.path.first,
                dismissed: defaults.bool(forKey: key)
            ) == false
        )
    }

    // MARK: - Fixtures

    /// A logged cook against a rung's curated recipe id, so `nextUncookedRung`
    /// treats that rung as done.
    static func cook(rung: GuidedCookout) -> CookLogEntry {
        CookLogEntry(
            id: UUID(),
            recipeID: rung.recipeID,
            recipeTitle: rung.dishTitle,
            cookedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
