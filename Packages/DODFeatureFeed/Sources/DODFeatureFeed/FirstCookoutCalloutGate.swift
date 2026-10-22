import DODSupport
import Foundation

/// The show/hide decision + persisted dismissal for the First Cookout callout.
///
/// **History.** DUT-571 rendered this nudge as an INLINE hero card at the top of
/// the Feed (`FeedView.firstCookoutHero` + `FirstCookoutHeroCard`). It was too
/// large and, being in the scroll content, it PUSHED the feed down for every
/// un-graduated cook. It's now a slim `TabBarCallout` overlay hosted by the App
/// shell (`RootView+FirstCookoutCallout.swift`), which points at the Tools tab —
/// a tab bar `FeedView` doesn't own, hence the move up to the shell.
///
/// The gating rules are UNCHANGED, so this type keeps them here in
/// `DODFeatureFeed` (rather than following the view up into the App target) for
/// two reasons: the rules are exercised by the package's fast L1 tests, and the
/// `GuidedCookout` / cook-log seam they read already lives at this layer.
public enum FirstCookoutCalloutGate {

    /// The persisted-dismissal `UserDefaults` key. **Unchanged from the DUT-571
    /// hero on purpose** (`…firstCookoutHero…`, despite the hero being gone): a
    /// cook who already dismissed the old hero must stay dismissed, not have the
    /// nudge come back as a callout. The `.v1` suffix is what a future copy /
    /// gating change would bump to deliberately re-surface it.
    ///
    /// Lives on `.standard` (the same store the Feed's layout toggle uses) — this
    /// is a UI preference, not shared data.
    public static let dismissedKey = "dod.feed.firstCookoutHero.dismissed.v1"

    /// The pure gating decision, factored out so the "new cook sees it / dismissed
    /// hides it / graduate hides it" rules are unit-testable without a SwiftUI
    /// host. Show it only when the cook state has loaded (so we never flash a
    /// stale rung 1 mid-load), the cook hasn't dismissed it, AND there IS a next
    /// un-cooked rung (a graduate past the campfire has `nil`).
    public static func shouldShow(
        cookStateLoaded: Bool,
        nextRung: GuidedCookout?,
        dismissed: Bool
    ) -> Bool {
        guard cookStateLoaded else { return false }
        guard !dismissed else { return false }
        return nextRung != nil
    }

    /// Derive the cook's next un-cooked rung from their logged cooks. Mirrors the
    /// hub's post-DUT-559 `loadCookState`: read the logged recipe ids and derive
    /// the next un-cooked rung. Fully graduated → `nil` → the callout stays hidden.
    public static func nextRung(from logs: [CookLogEntry]) -> GuidedCookout? {
        GuidedCookout.nextUncookedRung(cookedRecipeIDs: Set(logs.map(\.recipeID)))
    }
}
