import DODAnalytics
import DODSupport
import SwiftUI

// MARK: - DOD-ART-2 / DUT-243 / DUT-246 in-app article-link routing
//
// Extracted from `RootView.swift` so that file stays under the SwiftLint
// `file_length` cap. The referenced `@State` sinks are `internal` on
// `RootView` for exactly this cross-file access.

extension RootView {

    /// Widget URL handler (spec.md US-9 AC-9.2, US-17 AC-17.4). Recipe + feed
    /// routes switch to Feed and hand the link to the TabStack via
    /// `pendingDeepLink`; the saved route switches tabs; the tip route (DUT-457)
    /// shows the full cooking tip in a dialog. Fires `widgetOpened(kind:,
    /// recipeID:)` once per consumed link (T-323 / AC-17.9). Moved here from
    /// `RootView.swift` for the file_length cap (DUT-457).
    func handle(widgetLink link: WidgetDeepLink) {
        Telemetry.shared.send(.widgetOpened(kind: link.widgetKind, recipeID: link.recipeID))
        switch link {
        case .saved:
            selectedTab = .saved
        case .feed:
            selectedTab = .feed
            pendingDeepLink = link
        case .recipe(let id, _):
            // DUT-358: route a widget recipe tap through the App-Intent fetch-on-miss
            // resolver, so a cache + snapshot double-miss fetches the recipe instead
            // of `TabStack.consume` silently dropping the tap.
            selectedTab = .feed
            handle(intent: .openRecipe(id: id))
        case .tip(let index):
            // DUT-457 — show the full tip (widget truncated it) in a dialog.
            if let tip = CookingTip.tip(atIndex: index) {
                tipDialogText = tip
                showTipDialog = true
            }
        case .shoppingList:
            // DUT-480 — the iOS 18 Control Center control's `dod://` link path.
            routeToShoppingList()
        }
    }

    /// DUT-480 — switch to Saved (which hosts the Shopping List) and mint a
    /// fresh token so the Saved tab's `SavedView` pushes the Shopping List
    /// empty-first; a new UUID each time re-pushes on a repeat control tap.
    /// Shared by `handle(widgetLink: .shoppingList)` (the `dod://` path) and by
    /// `RootView`'s App Group pending-route reads (the Control Center path that
    /// can't rely on a URL hand-off). Non-private so `RootView.swift`'s
    /// scene-phase + cold-launch consumers can call it too.
    func routeToShoppingList() {
        selectedTab = .saved
        savedShoppingListToken = UUID()
    }

    /// DUT-480 — read + clear the iOS 18 Control Center control's App Group
    /// pending-route flag and, if the Shopping List was requested, route there.
    /// The control's `AppIntent` can't reliably hand us a `dod://` URL, so it
    /// sets `openAppWhenRun` + drops this flag instead; `RootView` drains it
    /// both at cold launch (the `.task`) and on each `.active` transition (the
    /// warm case). Take-once, so a stale flag can't re-trigger on a later
    /// foreground.
    func consumePendingControlRoute() {
        if ControlRouteStore()?.takePending() == .shoppingList {
            routeToShoppingList()
        }
    }

    /// The external-route sink for one tab. Feed/Saved/Search each own a
    /// sink so both layouts (phone tabs + iPad split detail) can hand every
    /// `TabStack` its own; Settings renders no article surface, so it keeps
    /// the inert constant.
    func externalRouteBinding(for tab: AppTab) -> Binding<ExternalRoute?> {
        switch tab {
        case .feed: return $feedExternalRoute
        case .saved: return $savedExternalRoute
        case .search: return $searchExternalRoute
        case .settings: return .constant(nil)
        }
    }

    /// DUT-250 — the hoisted navigation-stack binding for one tab. The paths
    /// live in `RootView`'s `tabPaths` dictionary (which survives the iPad
    /// size-class flip), and each `TabStack` reads/writes its slot through this
    /// binding instead of owning a local `@State`. A `get` on a missing key
    /// returns an empty stack; the `set` writes the slot back. Both layouts
    /// (phone tabs + iPad split detail) call this so a pushed detail persists
    /// across the compact↔regular tree swap.
    func pathBinding(for tab: AppTab) -> Binding<[RecipeRoute]> {
        Binding(
            get: { tabPaths[tab] ?? [] },
            set: { tabPaths[tab] = $0 }
        )
    }

    /// Custom `openURL` handler for in-app article recipe links. A
    /// `dutchovendaddy.com` recipe link is resolved to its post and pushed
    /// into the CURRENT tab's stack (DUT-243 — reading a round-up in Saved
    /// and tapping an inline link no longer yanks the user to Feed); a
    /// non-recipe `dutchovendaddy.com` URL or any off-site URL opens in the
    /// browser. Returns synchronously — the resolve is a fire-and-forget
    /// Task; flows that need the outcome use ``openRecipeLink(_:)`` via the
    /// `recipeLinkOpener` environment (DUT-246).
    func handleArticleLinkTap(_ url: URL) -> OpenURLAction.Result {
        guard AppDependencies.recipeSlug(fromDODURL: url) != nil else {
            return .systemAction
        }
        Task { @MainActor in _ = await openRecipeLink(url) }
        return .handled
    }

    /// DUT-246 — the awaitable core of the article-link routing. Resolves the
    /// link and routes it into the currently-selected tab's stack, returning
    /// `true` once in-app navigation actually happened. A URL that isn't a
    /// resolvable recipe (offline; or a slug that maps to a WP page, like the
    /// campfire heat-and-coals guide) falls back to the system browser and
    /// returns `false` so a covering sheet knows to stay put.
    func openRecipeLink(_ url: URL) async -> Bool {
        guard AppDependencies.recipeSlug(fromDODURL: url) != nil else {
            systemOpenURL(url)
            return false
        }
        // DUT-462: capture the tab that was selected WHEN the link was tapped,
        // BEFORE the async resolve. Reading `selectedTab` after the await would
        // route into whatever tab is selected when the resolve completes — if
        // the user switched tabs, or a guided-cookout sheet dismissed and
        // changed the selection mid-flight, the recipe lands in the wrong stack.
        let originTab = selectedTab
        guard let item = await dependencies.resolveRecipe(forArticleLink: url) else {
            systemOpenURL(url)
            return false
        }
        route(.recipe(item: item, autoStartCookMode: false), from: originTab)
        return true
    }

    /// DUT-243 — push a route onto the stack of the tab the link was tapped
    /// from (mirroring `onSelectRelated`, which appends in place) instead of
    /// hard-coding a switch to Feed. The forced `.feed` switch remains only
    /// for genuine external entry points (Spotlight / App Intents /
    /// notifications — see `handle(intent:)`) and for Settings, which has no
    /// article surface of its own. DUT-462: routes into `originTab` (captured
    /// at tap time), not `selectedTab` read after the resolve.
    private func route(_ route: RecipeRoute, from originTab: AppTab) {
        let destination = Self.linkRoutingDestination(for: originTab)
        // Settings has no article surface, so a link tapped there also brings
        // the user to Feed; every other tab keeps its own stack.
        if destination != originTab { selectedTab = destination }
        switch destination {
        case .feed: feedExternalRoute = .push(route)
        case .saved: savedExternalRoute = .push(route)
        case .search: searchExternalRoute = .push(route)
        case .settings: break  // unreachable: linkRoutingDestination never yields .settings
        }
    }

    /// DUT-462 / DUT-243 — which tab receives an in-app recipe route for a link
    /// tapped from `originTab`. Settings redirects to Feed (no article surface);
    /// every other tab keeps its own stack. Pure, so it's unit-testable without
    /// a SwiftUI host.
    nonisolated static func linkRoutingDestination(for originTab: AppTab) -> AppTab {
        originTab == .settings ? .feed : originTab
    }
}
