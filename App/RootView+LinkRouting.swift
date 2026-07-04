import DODAnalytics
import DODDesignSystem
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

    /// Routes a parsed `DeepLinkIntent` into tab + path state (US-10). Moved
    /// here from `RootView.swift` (file_length cap); `handle(widgetLink:)` above
    /// calls it, and it drives the DUT-549 failed-resolve recovery.
    func handle(intent: DeepLinkIntent) {
        switch intent {
        case .openSaved:
            selectedTab = .saved
        case .openRecipe(let id):
            selectedTab = .feed
            Task { @MainActor in
                applyDeepLinkResolve(await resolveRecipeRoute(id: id, autoStartCookMode: false))
            }
        case .startCookMode(let recipeID):
            selectedTab = .feed
            Task { @MainActor in
                applyDeepLinkResolve(await resolveRecipeRoute(id: recipeID, autoStartCookMode: true))
            }
        }
    }

    /// DUT-549 — apply the outcome of a deep-link resolve. A resolved route
    /// replaces the Feed stack (DUT-310, Back → tab root); a nil resolve (deleted
    /// post, or offline with no cache) surfaces the ``deepLinkFailedMessage``
    /// toast instead of leaving the user on the blank Feed the tab already
    /// switched to. Routed through the pure ``RecipeRouteResolver/outcome(for:)``
    /// so the route-vs-error decision is unit-testable without a SwiftUI host.
    private func applyDeepLinkResolve(_ route: RecipeRoute?) {
        switch RecipeRouteResolver.outcome(for: route) {
        case .route(let resolved):
            feedExternalRoute.enqueue(.replaceStack(resolved))
        case .failed:
            deepLinkErrorMessage = Self.deepLinkFailedMessage
        }
    }

    /// Resolve a deep-link recipe/post id into a route, fetching on a cache miss
    /// (T-632 / REG-20 / CL-101). Cache-hit (widget / Spotlight) stays
    /// network-free; cache-miss (notification — brand-new post) fetches by id so
    /// its `canonicalURL` is known, then routes to recipe-detail, which
    /// classifies recipe-vs-article via its JSON-LD fetch path (AC-4.11 /
    /// AC-37.2). The policy lives in ``RecipeRouteResolver`` so it is
    /// unit-testable without a SwiftUI host; this supplies the two live I/O edges.
    func resolveRecipeRoute(id: Int, autoStartCookMode: Bool) async -> RecipeRoute? {
        await RecipeRouteResolver.resolve(
            id: id,
            autoStartCookMode: autoStartCookMode,
            cachedLookup: { try await dependencies.store.recipeWithoutTouching(id: $0) },
            fetch: { try await dependencies.fetchListItem(forPostID: $0) }
        )
    }

    /// T-912 / DUT-551 (CL-306) — select the Cooking Tools hub tab and mint a
    /// fresh token that pushes the Shopping List onto the hub's NavigationStack.
    /// The Shopping List folded into the hub (its own tab was retired), so
    /// selecting the tab alone lands on the hub root, not the list — the token
    /// (consumed by the hub's `.task(id:)`) does the push. Mirrors the retired
    /// `savedShoppingListToken` pattern (CL-301) and preserves ALL four entry
    /// points at once because they all funnel through here:
    /// `handle(widgetLink: .shoppingList)` (the `dod://shopping-list` deep link),
    /// the DUT-534 snackbar "View" closure, the Saved header cart, and the iOS 18
    /// Control Center control (`consumePendingControlRoute`). A fresh UUID per
    /// call re-pushes if the user is already on the hub. Non-private so
    /// `RootView.swift`'s scene-phase + cold-launch consumers can call it too.
    func routeToShoppingList() {
        selectedTab = .cookingTools
        hubShoppingListToken = UUID()
    }

    /// T-912 / DUT-551 (CL-306) — select the Cooking Tools hub tab and mint a
    /// fresh token that presents Heat Coach (the hub's row #3 sheet). The
    /// per-recipe Heat Coach nudge (Recipe Detail) taps this to point the cook at
    /// the always-available hub tool rather than opening a one-off copy. Mirrors
    /// `routeToShoppingList()` — a fresh UUID per call re-presents if the user is
    /// already on the hub; the hub consumes it via `.task(id:)`.
    func routeToHeatCoach() {
        selectedTab = .cookingTools
        hubHeatCoachToken = UUID()
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
    /// FIFO queue so both layouts (phone tabs + iPad split detail) can hand
    /// every `TabStack` its own; Settings renders no article surface, so it
    /// keeps the inert constant.
    func externalRouteBinding(for tab: AppTab) -> Binding<ExternalRouteQueue> {
        switch tab {
        case .feed: return $feedExternalRoute
        case .saved: return $savedExternalRoute
        case .search: return $searchExternalRoute
        // T-912 / DUT-551 — the Cooking Tools hub renders no article surface, so
        // it keeps the inert constant (as the retired Grocery/Settings tabs did).
        case .cookingTools: return .constant(ExternalRouteQueue())
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
        case .feed: feedExternalRoute.enqueue(.push(route))
        case .saved: savedExternalRoute.enqueue(.push(route))
        case .search: searchExternalRoute.enqueue(.push(route))
        // unreachable: linkRoutingDestination only ever yields feed/saved/search
        // (it redirects the Cooking Tools hub — no article stack — to feed).
        case .cookingTools: break
        }
    }

    /// DUT-462 / DUT-243 — which tab receives an in-app recipe route for a link
    /// tapped from `originTab`. The T-912/DUT-551 Cooking Tools hub redirects to
    /// Feed (it renders no article surface with its own stack); every other tab
    /// keeps its own stack. Pure, so it's unit-testable without a SwiftUI host.
    nonisolated static func linkRoutingDestination(for originTab: AppTab) -> AppTab {
        switch originTab {
        case .cookingTools: .feed
        default: originTab
        }
    }

    /// DUT-549 — the copy shown when a deep link / notification recipe fails to
    /// resolve (deleted post, or offline with no cache). Plain, non-blaming, and
    /// consistent with the app's other transient snackbars.
    static let deepLinkFailedMessage = "Couldn't open that recipe. It may no longer be available."
}

/// DUT-549 — presents ``RootView/deepLinkErrorMessage`` as a bottom snackbar
/// that auto-dismisses, so a failed deep-link resolve gives the user feedback
/// instead of a silent blank Feed. Mirrors the Settings/Feed snackbar overlay
/// pattern (keyed by message so a new message restarts the timer). Extracted as
/// a `ViewModifier` in this file to keep `RootView.swift` under the file-length
/// cap.
struct DeepLinkErrorSnackbar: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message {
                Snackbar(message: message)
                    .id(message)
                    .padding(.bottom, DODSpacing.md)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onTapGesture { self.message = nil }
                    .task {
                        try? await Task.sleep(nanoseconds: 4_000_000_000)
                        self.message = nil
                    }
                    .accessibilityIdentifier("deep-link-error-snackbar")
            }
        }
        .animation(.easeInOut(duration: 0.2), value: message)
    }
}
