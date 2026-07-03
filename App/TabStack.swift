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
    @Binding var externalRoute: ExternalRoute?
    /// DUT-480 — external trigger for the iOS 18 Control Center control's
    /// `dod://shopping-list` deep link. Only the Saved tab consumes it (the
    /// Shopping List lives under Saved); `RootView` mints a fresh `UUID` on each
    /// control tap so a repeat tap re-pushes the empty list. Other tabs get the
    /// inert constant `nil`.
    @Binding var openShoppingListToken: UUID?
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
        externalRoute: Binding<ExternalRoute?> = .constant(nil),
        openShoppingListToken: Binding<UUID?> = .constant(nil)
    ) {
        self.tab = tab
        self.dependencies = dependencies
        self._path = path
        self._pendingDeepLink = pendingDeepLink
        self._externalRoute = externalRoute
        self._openShoppingListToken = openShoppingListToken
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
            // External route sink. `.task(id:)` (not `.onChange`) so a route
            // already non-nil when this tab is first instantiated — iPad
            // switching to the Feed tab, or a cold-launch intent — is still
            // consumed; `.onChange` only fires on a live transition (DUT-352).
            guard let route = externalRoute else { return }
            switch route {
            case .replaceStack(let destination):
                // DUT-310: deep links replace, so Back returns to the tab root.
                path = [destination]
            case .push(let destination):
                // DUT-243: in-app link taps append, so Back returns to the
                // article the user was reading.
                path.append(destination)
            }
            externalRoute = nil
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
                }
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
                onSelectCategory: { category in path.append(.category(category)) }
            )
        case .saved:
            SavedView(
                viewModel: SavedViewModel(dependencies: dependencies.savedDependencies()),
                // DUT-480 — the Control Center control's `dod://shopping-list`
                // tap flows in through this token, opening the Shopping List
                // empty-first.
                openShoppingListToken: $openShoppingListToken,
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
        case .settings:
            // T-823 / DUT-187 — Settings is now a first-class destination
            // (iPhone tab / iPad sidebar row) rendered inside the tab's own
            // NavigationStack, replacing the per-tab gear sheet.
            SettingsView(
                viewModel: settingsTabViewModel,
                onClearImageCache: { try await dependencies.store.clearImageCache() }
            )
        }
    }

    /// T-823 / DUT-187 — builds the `SettingsViewModel` for the Settings tab.
    /// Settings is now a first-class destination (iPhone tab between Saved and
    /// Search / iPad sidebar row) instead of the per-tab gear sheet, but the
    /// dependency surface is exactly what the old `SettingsToolbarModifier`
    /// (DUT-26) wired: the iCloud-Sync seam, Clear-Cache closure (passed at the
    /// `SettingsView` call site), notification-auth seam, the AVFoundation
    /// voice previewer, and the Keychain profile + photo stores.
    private var settingsTabViewModel: SettingsViewModel {
        #if canImport(UIKit)
        SettingsViewModel(
            dependencies: dependencies.settingsDependencies(),
            voicePreviewer: SystemVoicePreviewer(),
            profileStore: dependencies.profileStore,
            profilePhotoStore: dependencies.profilePhotoStore,
            requestNotificationAuthorization: {
                await dependencies.notificationService.requestAuthorization()
            }
        )
        #else
        SettingsViewModel(
            dependencies: dependencies.settingsDependencies(),
            voicePreviewer: SystemVoicePreviewer(),
            profileStore: dependencies.profileStore,
            requestNotificationAuthorization: {
                await dependencies.notificationService.requestAuthorization()
            }
        )
        #endif
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
                    dependencies: dependencies.recipeDetailDependencies()
                ),
                onSelectRelated: { related in path.append(.recipe(item: related)) },
                autoStartCookMode: autoStartCookMode
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
            // and `.shoppingList` (DUT-480, the Control Center control) directly
            // and never sets `pendingDeepLink`, so these are unreachable here.
            // Kept exhaustive so the compiler catches any future caller that
            // does forward the link through here.
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
