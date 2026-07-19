import DODAnalytics
import DODDesignSystem
import DODDomain
import DODFeatureCategories
import DODFeatureFeed
import DODFeatureRecipeDetail
import DODFeatureSaved
import DODFeatureSearch
import DODPersistence
import DODSupport
import SwiftUI
import WidgetKit

/// One tab's navigation stack. The per-tab `path` is owned by `RootView`
/// (DUT-250) and injected here as a `@Binding` so it survives the iPad
/// size-class flip, which re-instantiates the TabStack tree. The path used to
/// be local `@State`; hoisting it out of the parent's `Group` boundary keeps
/// a pushed detail alive across the compact↔regular swap.
struct TabStack: View {

    let tab: AppTab
    let dependencies: AppDependencies
    /// Inbound widget deep link, set by `RootView.handle(url:)`. Only the
    /// Feed tab consumes it — see the `.task(id:)` modifier in `body`.
    @Binding var pendingDeepLink: WidgetDeepLink?
    /// Binding-style sink so RootView can drive a tab's stack from outside —
    /// App Intents / Spotlight deep links (US-10, replace semantics) and
    /// in-app article-link taps (DUT-243, push semantics). Every tab gets a
    /// sink now so a link tapped in Saved/Search opens in place.
    ///
    /// DUT-463 / DUT-464 / DUT-319 — a FIFO ``ExternalRouteQueue`` (was a
    /// single-slot `ExternalRoute?`): it holds every enqueued route so a
    /// second one landing before the first is consumed isn't dropped
    /// (DUT-464), and it's drained on *appear* so a route that arrived while
    /// this tab was unmounted still fires once the tab mounts (DUT-463 /
    /// DUT-319), with stale routes discarded at drain.
    @Binding var externalRoute: ExternalRouteQueue
    /// DUT-534 / T-912 (DUT-551) — routes the Shopping List entry points to the
    /// Cooking Tools hub (`RootView.routeToShoppingList()` selects `.cookingTools`
    /// + mints the hub Shopping List token). Backs Recipe Detail's + the
    /// Feed/Search cards' "Added to your Shopping List" snackbar "View" action AND
    /// the Saved header cart. Threaded from `RootView` so this App view never
    /// reaches into the deep-link plumbing directly. Defaults to a no-op.
    let openShoppingList: () -> Void
    /// T-912 / DUT-551 (CL-306) — the header Settings gear (on every main tab)
    /// calls this to open the Settings sheet (`RootView.showSettingsSheet`).
    /// Threaded from `RootView` like `openShoppingList`; defaults to a no-op.
    let onOpenSettings: () -> Void
    /// T-912 / DUT-551 (CL-306) — the Cook Mode hub row routes here to pick a
    /// recipe to cook (Cook Mode can't launch without a recipe). Selects the
    /// Recipes tab. Threaded from `RootView`; defaults to a no-op.
    let onFindRecipe: () -> Void
    /// T-912 / DUT-551 (CL-306) — the per-recipe Heat Coach nudge (Recipe Detail)
    /// and the Cook Mode heat-step shortcut both point at the always-available
    /// hub Heat Coach. This closure (`RootView.routeToHeatCoach()`) selects
    /// `.cookingTools` + mints the hub Heat Coach token. Threaded from `RootView`
    /// like `openShoppingList`; defaults to a no-op. DUT-584 — carries an optional
    /// ``HeatCoachSeed`` so the per-recipe nudge can open the coach pre-answered.
    let openHeatCoach: (HeatCoachSeed?) -> Void
    /// DUT-571 — hero CTAs open the guided path; Bool = scrollToDumpCakes (dump-cake CTA).
    let startFirstCookout: (Bool) -> Void
    /// DUT-560 — the UNIFIED hub-tool reroute request, owned by `RootView` and
    /// bound only into the Cooking Tools tab (every tool entry point mints it via
    /// `route(toHubTool:)`). The hub consumes it via `.task(id:)` and opens the
    /// tool. Inert for other tabs.
    @Binding var hubPendingTool: HubToolRoute?
    /// DUT-461 (revised) — the Cooking Tip token, owned by `RootView` and bound
    /// only into the Cooking Tools tab. The Cooking Tip widget tap mints it; the
    /// hub consumes it via `.task(id:)` to pop to its root so the tip banner shows.
    /// Inert for other tabs.
    @Binding var hubTipToken: UUID?
    /// DUT — the one-shot "we came here to cook" arm (owned by `RootView`, bound
    /// only into the Feed tab). The hub's Cook Mode "Find a Recipe" sets it; the
    /// next Feed card tap consumes it so that recipe opens ALREADY in Cook Mode
    /// (like the StartCookMode deep link). `.constant(false)` for every other tab.
    @Binding var cookModeFindRecipeArmed: Bool
    /// DUT-546 (gap 3) — the single app-level ``CommentModerationStore`` owned by
    /// `RootView`, injected into every `RecipeDetailViewModel` this stack builds so
    /// a block applied on one recipe screen hides that author on an already-open
    /// second one live (shared `@Observable` set), not per-VM `UserDefaults` copies.
    let commentModeration: CommentModerationStore
    /// DUT-250 — the per-tab navigation stack is HOISTED into `RootView`-owned
    /// state and injected as a `@Binding` (was local `@State`). On iPad the
    /// size-class flip swaps `iPadSplit` (one keyed detail `TabStack`) for
    /// `phoneTabs` (four `TabStack`s); the differing identities tore down the old
    /// TabStack + its local `path`, dropping any pushed detail. Hoisting to
    /// `RootView` (which survives the flip) keeps the pushed stack alive.
    @Binding var path: [RecipeRoute]
    /// DUT-693 (PR7) — transient toast copy shown when a long-press card save
    /// fails to persist (`saveFromCard` returned `false`). Nil when hidden;
    /// surfaced via the reused ``DeepLinkErrorSnackbar`` overlay on `body`.
    /// Mirrors the DUT-549 deep-link failure snackbar so a silent catch no
    /// longer leaves the user without feedback.
    ///
    /// `internal` (not `private`) so `TabStack+Destination.swift` (split out
    /// for the file-length cap, DUT-1240) can surface the category-card save
    /// failure too.
    @State var saveErrorMessage: String?

    init(
        tab: AppTab,
        dependencies: AppDependencies,
        path: Binding<[RecipeRoute]> = .constant([]),
        pendingDeepLink: Binding<WidgetDeepLink?> = .constant(nil),
        externalRoute: Binding<ExternalRouteQueue> = .constant(ExternalRouteQueue()),
        openShoppingList: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {},
        onFindRecipe: @escaping () -> Void = {},
        openHeatCoach: @escaping (HeatCoachSeed?) -> Void = { _ in },
        startFirstCookout: @escaping (Bool) -> Void = { _ in },
        hubPendingTool: Binding<HubToolRoute?> = .constant(nil),
        hubTipToken: Binding<UUID?> = .constant(nil),
        cookModeFindRecipeArmed: Binding<Bool> = .constant(false),
        commentModeration: CommentModerationStore = CommentModerationStore()
    ) {
        self.tab = tab
        self.dependencies = dependencies
        self._path = path
        self._pendingDeepLink = pendingDeepLink
        self._externalRoute = externalRoute
        self.openShoppingList = openShoppingList
        self.onOpenSettings = onOpenSettings
        self.onFindRecipe = onFindRecipe
        self.openHeatCoach = openHeatCoach
        self.startFirstCookout = startFirstCookout
        self._hubPendingTool = hubPendingTool
        self._hubTipToken = hubTipToken
        self._cookModeFindRecipeArmed = cookModeFindRecipeArmed
        self.commentModeration = commentModeration
    }

    var body: some View {
        Group {
            if tab == .cookingTools {
                // DUT-551 crash fix — the hub owns its OWN `NavigationStack`; wrapping
                // it in TabStack's too doubly-nested them, crashing when the Shopping
                // List (with its title + toolbars) pushed onto the inner stack. Render
                // it bare (it needs no `RecipeRoute` destination).
                rootContent
            } else {
                NavigationStack(path: $path) {
                    rootContent
                        .navigationDestination(for: RecipeRoute.self) { route in
                            destination(for: route)
                        }
                }
            }
        }
        .task(id: pendingDeepLink) {
            // Widget deep link (only Feed consumes).
            guard tab == .feed, let link = pendingDeepLink else { return }
            await consume(link: link)
        }
        // DUT-693 (PR7) — surface the card-save failure toast (reuses the
        // DUT-549 snackbar overlay with its own a11y id). Set by the card
        // `onSave` sinks below when the store write doesn't persist.
        .modifier(
            DeepLinkErrorSnackbar(
                message: $saveErrorMessage,
                accessibilityID: "card-save-error-snackbar"
            )
        )
        .task(id: externalRoute) {
            // External route sink. `.task(id:)` (not `.onChange`) so a queue
            // already non-empty when this tab is first instantiated — iPad
            // switching to the Feed tab, or a cold-launch intent — is still
            // drained; `.onChange` only fires on a live transition (DUT-352).
            //
            // DUT-463 / DUT-464 / DUT-319 — drain EVERY queued route (was a
            // single-slot read). Because `.task(id:)` re-runs when the tab
            // (re)mounts, a route enqueued while this tab was unmounted is
            // delivered the moment it appears rather than sitting stuck; the
            // queue drops routes older than `staleAfter` so a long-stale one
            // never silently replaces the user's stack.
            consumeExternalRoutes()
        }
    }

    /// DUT-463 / DUT-464 / DUT-319 — drain the tab's external-route queue,
    /// applying each pending route to `path` in arrival order. `replaceStack`
    /// (deep links) resets the stack so Back lands on the tab root (DUT-310);
    /// `push` (in-app link taps) appends so Back returns to the article
    /// (DUT-243). Draining clears the queue and drops stale routes, so a route
    /// that resolved while this tab was unmounted fires on mount without a
    /// minutes-later surprise, and two routes landing within a frame are both
    /// delivered rather than one overwriting the other.
    private func consumeExternalRoutes() {
        guard !externalRoute.isEmpty else { return }
        for route in externalRoute.drain() {
            switch route {
            case .replaceStack(let destination):
                path = [destination]
            case .push(let destination):
                path.append(destination)
            }
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        switch tab {
        case .feed:
            FeedView(
                viewModel: FeedViewModel(dependencies: dependencies.feedDependencies()),
                // DUT-1229 fix — a pick made after the hub's Cook Mode "Find a
                // Recipe" (which armed the flag) opens already in Cook Mode; a
                // plain Feed browse leaves it false. Stays armed across repeated
                // picks (see `cookModeFindRecipeArmed`'s doc comment) — disarm
                // happens in `RootView` when the user leaves the Feed tab, not here.
                onSelect: { item in
                    path.append(Self.recipeRoute(for: item, cookModeArmed: cookModeFindRecipeArmed))
                },
                onSave: { item, report in
                    Task {
                        let didSave = await Self.saveFromCard(
                            item: item,
                            store: dependencies.store,
                            publisher: dependencies.savedWidgetPublisher()
                        )
                        report(didSave)  // DUT-629 — revert optimistic flip on failure
                        if !didSave { saveErrorMessage = Self.saveFailedMessage }  // DUT-693
                    }
                },
                // DUT-534 Part 2 — the card snackbar's "View" opens the Shopping
                // List, same closure Recipe Detail's Part 1 snackbar routes to.
                openShoppingList: openShoppingList,
                // T-912 / DUT-551 (CL-306) — the Feed header trailing slot now
                // hosts the Settings gear (the old Cooking Tools menu is retired).
                onOpenSettings: onOpenSettings,
                // DUT-571 — both hero CTAs open the guided path; DUT — "Or Cook a Dump
                // Cake" (true) scrolls to Anytime Treats, primary "Start" (false) doesn't.
                onStartFirstCookout: { startFirstCookout(false) },
                onCookDumpCake: { startFirstCookout(true) }
            )
        case .search:
            SearchView(
                viewModel: SearchViewModel(dependencies: dependencies.searchDependencies()),
                onSelect: { item in path.append(.recipe(item: item)) },
                onSave: { item, report in
                    Task {
                        let didSave = await Self.saveFromCard(
                            item: item,
                            store: dependencies.store,
                            publisher: dependencies.savedWidgetPublisher()
                        )
                        report(didSave)  // DUT-629 — revert optimistic flip on failure
                        if !didSave { saveErrorMessage = Self.saveFailedMessage }  // DUT-693
                    }
                },
                // T-799 / CL-193: browse-category tap → push the category's
                // recipes. `.category` resolves via the shared
                // `navigationDestination(for: RecipeRoute.self)` →
                // `CategoryRecipesView`. Since T-800 (CL-194 / DUT-113)
                // removed the Categories tab, this is now the only entry
                // point into the category-browse → recipes flow.
                onSelectCategory: { category in path.append(.category(category)) },
                // DUT-534 Part 2 — the card snackbar's "View" opens the Shopping
                // List, same closure Recipe Detail's Part 1 snackbar routes to.
                openShoppingList: openShoppingList,
                onOpenSettings: onOpenSettings  // DUT-551 (CL-306) — header gear
            )
        case .saved:
            SavedView(
                viewModel: SavedViewModel(dependencies: dependencies.savedDependencies()),
                onSelect: { recipe in path.append(.recipe(item: Self.listItem(from: recipe))) },
                onSave: { recipe, report in
                    Task {
                        let didSave = await Self.saveFromCard(
                            item: Self.listItem(from: recipe),
                            store: dependencies.store,
                            publisher: dependencies.savedWidgetPublisher()
                        )
                        report(didSave)  // DUT-629 — restore the row on failure
                        if !didSave { saveErrorMessage = Self.saveFailedMessage }  // DUT-693
                    }
                },
                onOpenSettings: onOpenSettings  // DUT-551 (CL-306) — header gear
            )
        case .cookingTools:
            // T-912 / DUT-551 (CL-306) — the Cooking Tools hub. Replaces the
            // retired Grocery List tab (the Shopping List is now a pushed row
            // inside the hub, reached via `hubPendingTool`) and the retired
            // Settings tab (Settings moved to a header gear). Renders every
            // utility in meal-making order; the Shopping List still reads the
            // SAME App-Group store via `GroceryTabRoot`.
            CookingToolsHubView(
                dependencies: dependencies,
                pendingTool: $hubPendingTool,
                tipToken: $hubTipToken,
                onFindRecipe: onFindRecipe,
                onOpenSettings: onOpenSettings  // DUT-551 (CL-306) — header gear
            )
        }
    }

    // `destination(for:)` (the `.recipe` / `.category` push destinations) lives
    // in `TabStack+Destination.swift`, and `saveFromCard(...)` / `listItem(from:)`
    // (the shared card-save path, DUT-629) live in `TabStack+CardSave.swift` —
    // both keep this file under the SwiftLint `file_length` cap.

    /// Service a widget deep link by pushing the recipe detail onto our
    /// path. Resolution preference, best → worst:
    ///   1. The same RecipeListItem the cache has — gives the detail
    ///      screen everything it needs to render the cell instantly.
    ///   2. The widget snapshot entry — same fields, written by this very
    ///      build, so equivalently safe.
    /// If neither is available the deep link is dropped silently; the next
    /// time the feed refreshes we'll re-write the snapshot.
    ///
    /// AC-9.2 / spec.md US-9.
    private func consume(link: WidgetDeepLink) async {
        defer { pendingDeepLink = nil }
        switch link {
        case .recipe(let id, _):
            // `source` is consumed at the RootView analytics layer; the
            // detail-push behaviour is the same regardless of which widget
            // emitted the URL.
            if let cached = await cachedListItem(forID: id) {
                path = [.recipe(item: cached)]
            } else if let snapshotItem = snapshotListItem(forID: id) {
                path = [.recipe(item: snapshotItem)]
            }
        case .feed:
            // Already on Feed (RootView set the tab); just clear any push
            // stack so the user lands on the root list.
            path = []
        case .saved, .tip, .shoppingList, .cookingTool:
            // RootView routes `.saved` (Saved tab), `.tip` (DUT-457 dialog),
            // `.shoppingList` (DUT-480 control → T-912/DUT-551 Cooking Tools tab +
            // hub Shopping List token), and `.cookingTool` (DUT-674 URL fallback
            // for the DUT-560 configurable control) directly and never set
            // `pendingDeepLink`, so these are unreachable here. Kept exhaustive so
            // the compiler catches any future caller that forwards a link here.
            break
        }
    }

    private func cachedListItem(forID id: Int) async -> RecipeListItem? {
        try? await dependencies.store.listItems(forIDs: [id]).first
    }

    private func snapshotListItem(forID id: Int) -> RecipeListItem? {
        guard let snapshot = WidgetSnapshotStore()?.read() else { return nil }
        return snapshot.entries.first(where: { $0.id == id }).map(RecipeListItem.init(snapshot:))
    }
}
