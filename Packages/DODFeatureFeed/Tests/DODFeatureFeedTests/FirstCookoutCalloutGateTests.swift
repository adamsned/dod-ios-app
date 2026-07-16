import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureFeed

/// Coverage for the First Cookout nudge's gating + rung-seeding logic.
///
/// These rules shipped with the DUT-571 top-of-feed hero card and are CARRIED OVER
/// UNCHANGED now that the nudge is a slim tab-bar callout hosted by the App shell:
/// the hero's view moved, its gating didn't. The suite therefore still asserts the
/// same rules (new cook sees it / dismissed hides it / graduate hides it / hidden
/// until cook state loads) plus the rung seed, now against
/// ``FirstCookoutCalloutGate`` instead of the retired `FeedView` statics.
///
/// The decision and the rung-seed are pure/testable without a SwiftUI host, which
/// is exactly why they stayed in this package when the view moved up to the App
/// target (mirrors `CookChooserFlowTests`).
@MainActor
@Suite("First Cookout callout gate")
struct FirstCookoutCalloutGateTests {

    // MARK: - Gating: shouldShow

    @Test func newCookSeesCalloutSeededToFirstRung() async {
        // A brand-new cook: empty cook log, not dismissed. The callout must show,
        // seeded to the first rung ("Your First Cookout").
        let dependencies = FakeFeedDependencies()  // no cooks
        let viewModel = FeedViewModel(dependencies: dependencies)
        let nextRung = FirstCookoutCalloutGate.nextRung(from: await viewModel.cookLogs())
        #expect(nextRung == GuidedCookout.path.first)
        #expect(nextRung?.isFirstRung == true)
        #expect(
            FirstCookoutCalloutGate.shouldShow(
                cookStateLoaded: true,
                nextRung: nextRung,
                dismissed: false
            )
        )
    }

    @Test func dismissedCookHidesCallout() {
        // Even a new cook (a real next rung) must NOT see it once dismissed.
        #expect(
            FirstCookoutCalloutGate.shouldShow(
                cookStateLoaded: true,
                nextRung: GuidedCookout.path.first,
                dismissed: true
            ) == false
        )
    }

    @Test func graduatedCookHidesCallout() async {
        // A cook who has logged every rung has no next un-cooked rung → hidden.
        let dependencies = FakeFeedDependencies()
        dependencies.cooks = GuidedCookout.path.map(Self.cook(rung:))
        let viewModel = FeedViewModel(dependencies: dependencies)
        let nextRung = FirstCookoutCalloutGate.nextRung(from: await viewModel.cookLogs())
        #expect(nextRung == nil)
        #expect(
            FirstCookoutCalloutGate.shouldShow(
                cookStateLoaded: true,
                nextRung: nextRung,
                dismissed: false
            ) == false
        )
    }

    @Test func returningCookSeesCalloutSeededToNextRung() async {
        // One rung logged → still shows, seeded to the SECOND rung, not a stale rung 1.
        let dependencies = FakeFeedDependencies()
        dependencies.cooks = [Self.cook(rung: GuidedCookout.path[0])]
        let viewModel = FeedViewModel(dependencies: dependencies)
        let nextRung = FirstCookoutCalloutGate.nextRung(from: await viewModel.cookLogs())
        #expect(nextRung == GuidedCookout.path[1])
        #expect(nextRung?.isFirstRung == false)
        #expect(
            FirstCookoutCalloutGate.shouldShow(
                cookStateLoaded: true,
                nextRung: nextRung,
                dismissed: false
            )
        )
    }

    @Test func calloutHiddenUntilCookStateLoads() {
        // Before the shell's `.task` loads the real cook state, the callout must not
        // flash — the loaded gate keeps it hidden even for a would-be new cook.
        #expect(
            FirstCookoutCalloutGate.shouldShow(
                cookStateLoaded: false,
                nextRung: GuidedCookout.path.first,
                dismissed: false
            ) == false
        )
    }

    // MARK: - Dismissal persistence

    /// The dismissal key is a MIGRATION CONTRACT, not an implementation detail: the
    /// hero → callout redesign deliberately reuses DUT-571's key verbatim so a cook
    /// who already dismissed the inline hero is not re-nudged by the callout. Pin
    /// the literal so a well-meaning rename to match the new component's name (which
    /// would silently re-show the nudge to every dismissed user) fails here.
    @Test func dismissedKeyIsUnchangedFromTheRetiredHero() {
        #expect(FirstCookoutCalloutGate.dismissedKey == "dod.feed.firstCookoutHero.dismissed.v1")
    }

    @Test func dismissalPersistsThroughAppStorageKey() {
        // The X flips the `@AppStorage` boolean; the gating function then reads it
        // back as dismissed. Assert the key round-trips through the same `.standard`
        // store the view binds to (mirrors the layout-toggle key).
        let key = FirstCookoutCalloutGate.dismissedKey
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: key)
        defer { defaults.removeObject(forKey: key) }

        #expect(defaults.bool(forKey: key) == false)
        // Simulate the onDismiss write.
        defaults.set(true, forKey: key)
        #expect(defaults.bool(forKey: key))
        #expect(
            FirstCookoutCalloutGate.shouldShow(
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
