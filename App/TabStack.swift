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
    /// T-912 / DUT-551 (CL-306) — iPhone Settings gear. The Feed header's
    /// trailing `gearshape` button calls this to open the Settings sheet
    /// (`RootView.showSettingsSheet`). Threaded from `RootView` like
    /// `openShoppingList`; defaults to a no-op for terse call sites.
    let onOpenSettings: () -> Void
    /// T-912 / DUT-551 (CL-306) — the Cook Mode hub row routes here to pick a
    /// recipe to cook (Cook Mode can't launch without a recipe). Selects the
    /// Recipes tab. Threaded from `RootView`; defaults to a no-op.
    let onFindRecipe: () -> Void
    /// T-912 / DUT-551 (CL-306) — the per-recipe Heat Coach nudge (Recipe Detail)
    /// and the Cook Mode heat-step shortcut both point at the always-available
    /// hub Heat Coach. This closure (`RootView.routeToHeatCoach()`) selects
    /// `.cookingTools` + mints the hub Heat Coach token. Threaded from `RootView`
    /// like `openShoppingList`; defaults to a no-op.
    let openHeatCoach: () -> Void
    /// T-912 / DUT-551 (CL-306) — the Shopping List reroute token, owned by
    /// `RootView` and bound only into the Cooking Tools tab (all four Shopping
    /// List entry points mint it via `routeToShoppingList()`). The hub consumes
    /// it via `.task(id:)` and pushes the Shopping List. Inert for other tabs.
    @Binding var hubShoppingListToken: UUID?
    /// T-912 / DUT-551 (CL-306) — the Heat Coach reroute token, owned by
    /// `RootView` and bound only into the Cooking Tools tab. `routeToHeatCoach()`
    /// mints it (from the per-recipe nudge); the hub consumes it via `.task(id:)`
    /// and presents Heat Coach. Inert for other tabs.
    @Binding var hubHeatCoachToken: UUID?
    /// DUT-461 (revised) — the Cooking Tip token, owned by `RootView` and bound
    /// only into the Cooking Tools tab. The Cooking Tip widget tap mints it; the
    /// hub consumes it via `.task(id:)` to pop to its root so the tip banner shows.
    /// Inert for other tabs.
    @Binding var hubTipToken: UUID?
    /// DUT-546 (gap 3) — the single app-level ``CommentModerationStore`` owned
    /// by `RootView`, injected into every `RecipeDetailViewModel` this stack
    /// builds so a block applied on one recipe screen hides that author on an
    /// already-open second recipe screen live (shared `@Observable` set),
    /// instead of each detail VM reading its own private `UserDefaults` copy.
    let commentModeration: CommentModerationStore
    /// DUT-250 — the per-tab navigation stack is now HOISTED into
    /// `RootView`-owned state and injected as a `@Binding`. Previously this
    /// was a local `@State private var path`, but on iPad the size-class flip
    /// (Slide Over / Split View / Stage Manager resize) swaps `RootView`'s
    /// `iPadSplit` (one detail `TabStack`, keyed `.id(selectedTab)`) for
    /// `phoneTabs` (four `TabStack`s) — two structurally different trees. The
    /// TabStack identities differ across the boundary, so SwiftUI tore down
    /// the old TabStack and its local `path`, dropping any pushed detail back
    /// to the tab root. Hoisting the path to `RootView` (which itself survives
    /// the flip, like `selectedTab`) keeps the pushed stack alive.
    @Binding var path: [RecipeRoute]

    init(
        tab: AppTab,
        dependencies: AppDependencies,
        path: Binding<[RecipeRoute]> = .constant([]),
        pendingDeepLink: Binding<WidgetDeepLink?> = .constant(nil),
        externalRoute: Binding<ExternalRouteQueue> = .constant(ExternalRouteQueue()),
        openShoppingList: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {},
        onFindRecipe: @escaping () -> Void = {},
        openHeatCoach: @escaping () -> Void = {},
        hubShoppingListToken: Binding<UUID?> = .constant(nil),
        hubHeatCoachToken: Binding<UUID?> = .constant(nil),
        hubTipToken: Binding<UUID?> = .constant(nil),
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
        self._hubShoppingListToken = hubShoppingListToken
        self._hubHeatCoachToken = hubHeatCoachToken
        self._hubTipToken = hubTipToken
        self.commentModeration = commentModeration
    }

    var body: some View {
        NavigationStack(path: $path) {
            rootContent
                .navigationDestination(for: RecipeRoute.self) { route in
                    destination(for: route)
                }
        }
        .task(id: pendingDeepLink) {
            // Widget deep link (only Feed consumes).
            guard tab == .feed, let link = pendingDeepLink else { return }
            await consume(link: link)
        }
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
                onSelect: { item in path.append(.recipe(item: item)) },
                onSave: { item in
                    Task {
                        await Self.saveFromCard(
                            item: item,
                            store: dependencies.store,
                            publisher: dependencies.savedWidgetPublisher()
                        )
                    }
                },
                // DUT-534 Part 2 — the card snackbar's "View" opens the Shopping
                // List, same closure Recipe Detail's Part 1 snackbar routes to.
                openShoppingList: openShoppingList,
                // T-912 / DUT-551 (CL-306) — the Feed header trailing slot now
                // hosts the Settings gear (the old Cooking Tools menu is retired).
                onOpenSettings: onOpenSettings
            )
        case .search:
            SearchView(
                viewModel: SearchViewModel(dependencies: dependencies.searchDependencies()),
                onSelect: { item in path.append(.recipe(item: item)) },
                onSave: { item in
                    Task {
                        await Self.saveFromCard(
                            item: item,
                            store: dependencies.store,
                            publisher: dependencies.savedWidgetPublisher()
                        )
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
                openShoppingList: openShoppingList
            )
        case .saved:
            SavedView(
                viewModel: SavedViewModel(dependencies: dependencies.savedDependencies()),
                onSelect: { recipe in path.append(.recipe(item: Self.listItem(from: recipe))) },
                onSave: { recipe in
                    Task {
                        await Self.saveFromCard(
                            item: Self.listItem(from: recipe),
                            store: dependencies.store,
                            publisher: dependencies.savedWidgetPublisher()
                        )
                    }
                }
            )
        case .cookingTools:
            // T-912 / DUT-551 (CL-306) — the Cooking Tools hub. Replaces the
            // retired Grocery List tab (the Shopping List is now a pushed row
            // inside the hub, reached via `hubShoppingListToken`) and the retired
            // Settings tab (Settings moved to a header gear). Renders every
            // utility in meal-making order; the Shopping List still reads the
            // SAME App-Group store via `GroceryTabRoot`.
            CookingToolsHubView(
                dependencies: dependencies,
                shoppingListToken: $hubShoppingListToken,
                heatCoachToken: $hubHeatCoachToken,
                tipToken: $hubTipToken,
                onFindRecipe: onFindRecipe
            )
        }
    }

    @ViewBuilder
    private func destination(for route: RecipeRoute) -> some View {
        switch route {
        case .recipe(let item, let autoStartCookMode):
            let canonical =
                item.canonicalURL
                ?? URL(string: "https://www.dutchovendaddy.com/") ?? URL(filePath: "/")
            RecipeDetailView(
                viewModel: RecipeDetailViewModel(
                    listItem: item,
                    canonicalURL: canonical,
                    dependencies: dependencies.recipeDetailDependencies(),
                    // DUT-546 — inject the shared store so a block on one open
                    // recipe screen live-hides that author on another.
                    commentModeration: commentModeration
                ),
                onSelectRelated: { related in path.append(.recipe(item: related)) },
                autoStartCookMode: autoStartCookMode,
                // DUT-534 — the Snackbar "View" action opens the Shopping List.
                openShoppingList: openShoppingList,
                // DUT-535 — present the ingredient-selection sheet on "Add to
                // Shopping List" (pick which ingredients), replacing the DUT-534
                // immediate add-all.
                addToShoppingListSheet: dependencies.addToShoppingListSheetBuilder(),
                // T-912 / DUT-551 — the per-recipe Heat Coach nudge routes to the
                // hub tool; the Cook Mode heat-step shortcut presents Heat Coach
                // as a sheet over the full-screen cover (a tab switch would be
                // invisible beneath it).
                openHeatCoach: openHeatCoach,
                heatCoachSheet: { AnyView(NavigationStack { HeatCoachView() }) }
            )
            .onAppear {
                Telemetry.shared.send(.screenView(name: "recipe_detail"))
            }
        case .category(let category):
            CategoryRecipesView(
                viewModel: CategoryRecipesViewModel(
                    category: category,
                    dependencies: dependencies.categoriesDependencies()
                ),
                onSelect: { item in path.append(.recipe(item: item)) },
                onSave: { item in
                    Task {
                        await Self.saveFromCard(
                            item: item,
                            store: dependencies.store,
                            publisher: dependencies.savedWidgetPublisher()
                        )
                    }
                }
            )
            .onAppear {
                Telemetry.shared.send(.screenView(name: "category_recipes"))
            }
        }
    }

    /// US-34 / AC-34.2 / AC-34.3 — execute the same save side-effect as
    /// the recipe-detail nav-bar bookmark tap (AC-4.7 / AC-5.1), invoked
    /// from a `RecipeCard`'s long-press context menu. Caches the listItem
    /// first so freshly-fetched REST hits (Search/Categories) have a row
    /// to mutate, then toggles `isSaved`, then republishes the
    /// saved-recipes widget snapshot so the home-screen widget timeline
    /// refreshes the same frame the user expects. Per CL-59's
    /// always-"Save" decision, this is idempotent in the user-visible
    /// sense — a follow-up long-press just toggles state again with no
    /// user-visible error path. Errors are logged + swallowed so the menu
    /// never surfaces a crash to the user.
    private static func saveFromCard(
        item: RecipeListItem,
        store: RecipeStore,
        publisher: SavedRecipesWidgetPublisher
    ) async {
        do {
            try await store.cache(listItem: item)
            _ = try await store.toggleSaved(id: item.id)
        } catch {
            DODLog.persistence.error("save-from-card failed: \(String(describing: error))")
            return
        }
        // T-770 / CL-167 (DUT-76) — `publisher` is built by
        // `AppDependencies.savedWidgetPublisher()` with the hero-image
        // prefetcher, so saving from a card (where the recipe's hero bytes are
        // usually not cached yet) still bridges the photo into the widget.
        await publisher.publish()
    }

    private static func listItem(from recipe: Recipe) -> RecipeListItem {
        RecipeListItem(
            id: recipe.id,
            title: recipe.title,
            excerpt: recipe.excerpt,
            heroImage: recipe.heroImage,
            publishedAt: recipe.publishedAt,
            totalTimeDisplay: nil,
            canonicalURL: recipe.canonicalURL
        )
    }

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
        case .saved, .tip, .shoppingList:
            // RootView routes `.saved` (Saved tab), `.tip` (the DUT-457 dialog),
            // and `.shoppingList` (DUT-480 Control Center control → T-912/DUT-551
            // now selects the Cooking Tools tab + mints the hub Shopping List
            // token) directly and never sets `pendingDeepLink`, so these are
            // unreachable here. Kept exhaustive so the compiler catches any future
            // caller that does forward the link through here.
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
