import DODDesignSystem
import DODSupport
import SwiftUI

// DUT-571 — surface the (previously dead) `FirstCookoutHeroCard` at the top of
// the Feed so a brand-new cook lands on the guided "one guaranteed win" front
// door the onboarding tour promises. Split into its own extension (mirroring
// `FeedView+ShoppingList.swift`) to keep `FeedView.swift` under the SwiftLint
// `file_length` / `type_body_length` caps. The card is an ADDITIONAL,
// dismissible entry point — the toolbar/hub flame re-entry stays put.

extension FeedView {

    /// DUT-571 — the persisted-dismissal UserDefaults key. Versioned (`.v1`) so a
    /// future copy/gating change can re-surface the card without colliding with an
    /// old dismissal. Lives on `.standard` (the same store `RecipeListLayout` uses
    /// for the Feed's layout toggle) — this is a UI preference, not shared data.
    static let firstCookoutHeroDismissedKey = "dod.feed.firstCookoutHero.dismissed.v1"

    /// DUT-571 — the top-of-feed hero. Rendered only once the feed is ready
    /// (`.idle` / `.loaded` / `.loadingMore` — never the loading skeleton or an
    /// error/empty state; those branches don't render `list` at all) AND the
    /// gating below says a new / un-graduated, non-dismissed cook should see it.
    /// `heroCookout` is seeded in `loadFirstCookoutHeroState()` from the cook's
    /// real next un-cooked rung, so a returning cook sees "Your Next Cookout",
    /// not a stale rung 1.
    @ViewBuilder
    var firstCookoutHero: some View {
        if Self.shouldShowFirstCookoutHero(
            cookStateLoaded: heroCookStateLoaded,
            nextRung: heroCookout,
            dismissed: firstCookoutHeroDismissed
        ), let cookout = heroCookout {
            FirstCookoutHeroCard(
                cookout: cookout,
                onStart: { onStartFirstCookout?() },
                onDismiss: {
                    firstCookoutHeroDismissed = true
                },
                onCookDumpCake: { onCookDumpCake?() }
            )
            .padding(.horizontal, DODSpacing.md)
            .padding(.top, DODSpacing.md)
            .padding(.bottom, DODSpacing.md)
        }
    }

    /// DUT-571 — the pure gating decision, factored out so the "new cook sees it /
    /// dismissed hides it / graduate hides it" rules are unit-testable without a
    /// SwiftUI host. Show the card only when the cook state has loaded (so we
    /// never flash a stale rung 1 mid-load), the cook hasn't dismissed it, AND
    /// there IS a next un-cooked rung (a graduate past the campfire has `nil`).
    static func shouldShowFirstCookoutHero(
        cookStateLoaded: Bool,
        nextRung: GuidedCookout?,
        dismissed: Bool
    ) -> Bool {
        guard cookStateLoaded else { return false }
        guard !dismissed else { return false }
        return nextRung != nil
    }

    /// DUT-571 — load the cook's real next rung for the hero. Mirrors the hub's
    /// post-DUT-559 `loadCookState`: read the logged recipe ids from the same
    /// `cookLogs()` seam and derive the next un-cooked rung. Runs in a `.task` so
    /// it never blocks the feed's own load; a failure yields an empty set (a
    /// brand-new cook), which seeds rung 1. Fully graduated → `nil` → hidden.
    func loadFirstCookoutHeroState() async {
        let logs = await viewModel.cookLogs()
        let cookedRecipeIDs = Set(logs.map(\.recipeID))
        heroCookout = GuidedCookout.nextUncookedRung(cookedRecipeIDs: cookedRecipeIDs)
        heroCookStateLoaded = true
    }
}
