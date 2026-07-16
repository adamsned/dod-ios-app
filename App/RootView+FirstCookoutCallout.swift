import DODDesignSystem
import DODFeatureFeed
import DODSupport
import SwiftUI

/// The First Cookout nudge: a slim ``TabBarCallout`` floating just above the
/// bottom tab bar, its tail pointing down at the **Tools** tab.
///
/// **Why it lives on `RootView` and not `FeedView`.** DUT-571 shipped this nudge
/// as an inline hero card at the top of the Feed. Two problems: it was too big,
/// and being inside the scroll content it pushed the feed down for every
/// un-graduated cook. The replacement must (a) overlay rather than displace, and
/// (b) point at the Tools tab button — which `FeedView` doesn't own, because the
/// tab bar belongs to `RootView.phoneTabs`. Both requirements put the host here,
/// at the app shell, above the `TabView`.
///
/// **iPhone only, by construction.** `RootView` renders `phoneTabs` (a `TabView`
/// with a bottom tab bar) only in compact width; the regular-width iPad layout is
/// `iPadSplit`, a `NavigationSplitView` whose tabs are SIDEBAR ROWS — there is no
/// bottom tab bar there for a tail to point at. So the overlay is attached to
/// `phoneTabs` only, and the "does the tail line up on iPad?" question dissolves:
/// iPad simply never shows it. iPad users still reach the flow from the Tools
/// sidebar row and the hub's own First Cookout card.
extension RootView {

    /// The tail's horizontal aim, as a fraction of the tab bar's full width.
    ///
    /// A tab bar distributes its items evenly, so item `i` of `n` is centered at
    /// `(i + 0.5) / n`. Both numbers are derived from ``AppTab/allCases`` — the
    /// single source of truth for tab-bar order — so adding, removing, or
    /// reordering a tab re-aims the tail automatically instead of stranding a
    /// hard-coded offset. Falls back to dead center if `.cookingTools` somehow
    /// isn't in `allCases` (unreachable; keeps this total).
    ///
    /// See ``TabBarCallout/tailCenterFraction`` for the accuracy this buys: the
    /// error is `(fraction - 0.5) * 2m` for a tab bar inset `m` per side, which
    /// for the Tools tab (3rd of 4 → 0.625) is a few points against a ~90pt slot.
    static var toolsTabTailFraction: CGFloat {
        let tabs = AppTab.allCases
        guard let index = tabs.firstIndex(of: .cookingTools), !tabs.isEmpty else { return 0.5 }
        return (CGFloat(index) + 0.5) / CGFloat(tabs.count)
    }

    /// The overlay itself.
    ///
    /// **Feed-only, and above the tab bar, both structurally.** `phoneTabs`
    /// attaches this via `.overlay(alignment: .bottom)` to the `.feed` tab's
    /// `TabStack` — i.e. INSIDE the `TabView`, on one tab. That buys two
    /// properties for free rather than by arithmetic:
    ///
    /// 1. It renders only when the Feed tab is showing, so a tail aimed at Tools
    ///    can never float over Saved or Search.
    /// 2. A `TabView` child's bottom safe-area inset is exactly the tab bar, and
    ///    overlays honour their host's safe area, so `.bottom` lands the bubble
    ///    just ABOVE the tab bar (never under it) with no hard-coded bar height.
    ///
    /// And being an overlay, it never participates in the feed's layout — the feed
    /// scrolls underneath it, which is the whole point of the redesign.
    @ViewBuilder
    var firstCookoutCallout: some View {
        if FirstCookoutCalloutGate.shouldShow(
            cookStateLoaded: firstCookoutCookStateLoaded,
            nextRung: firstCookoutNextRung,
            dismissed: firstCookoutCalloutDismissed
        ) {
            TabBarCallout(
                message: "New to cast iron? Your First Cookout starts here.",
                // Echoes the Tools tab's own glyph, tying the bubble to the tab
                // its tail points at. Burnt orange on the icon only.
                systemImage: "frying.pan.fill",
                tailCenterFraction: Self.toolsTabTailFraction,
                accessibilityID: "first-cookout-callout",
                dismissAccessibilityID: "first-cookout-callout-dismiss",
                activateActionName: "Open Your First Cookout",
                onActivate: {
                    // The same path the retired hero's primary CTA took.
                    route(toHubTool: .firstCookout(scrollToDumpCakes: false))
                },
                onDismiss: { firstCookoutCalloutDismissed = true }
            )
            // Gated on Reduce Motion — with it on, the callout just appears.
            .transition(reduceMotion ? .identity : .opacity.combined(with: .scale(scale: 0.96)))
        }
    }

    /// Load the cook's real next rung. Mirrors the hero's `loadFirstCookoutHeroState()`
    /// semantics exactly: read the logged cooks from the SAME `cookLogs()` seam the
    /// Feed and the hub use, derive the next un-cooked rung, then flip the loaded
    /// flag so the callout can't flash a stale rung 1 mid-load. A failure yields an
    /// empty set (a brand-new cook), which seeds rung 1; fully graduated → `nil` →
    /// stays hidden. Runs in its own `.task` so it never blocks the shell's launch.
    func loadFirstCookoutCalloutState() async {
        let logs = (try? await dependencies.feedDependencies().cookLogs()) ?? []
        firstCookoutNextRung = FirstCookoutCalloutGate.nextRung(from: logs)
        firstCookoutCookStateLoaded = true
    }
}
