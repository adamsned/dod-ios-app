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

/// One tab's navigation stack. Each tab gets its own `@State` path so
/// SwiftUI's binding identity stays stable across re-renders of the host
/// TabView — moving the @State out of the parent was the fix for DOD-NAV-1.
struct TabStack: View {

    let tab: AppTab
    let dependencies: AppDependencies
    /// Inbound widget deep link, set by `RootView.handle(url:)`. Only the
    /// Feed tab consumes it — see the `.task(id:)` modifier in `body`.
    @Binding var pendingDeepLink: WidgetDeepLink?
    /// Binding-style sink so RootView can drive a tab's stack from outside —
    /// used by App Intents / Spotlight deep links (US-10). Optional so the
    /// non-feed stacks don't need to plumb anything.
    @Binding var externalRoute: RecipeRoute?
    @State private var path: [RecipeRoute] = []

    init(
        tab: AppTab,
        dependencies: AppDependencies,
        pendingDeepLink: Binding<WidgetDeepLink?> = .constant(nil),
        externalRoute: Binding<RecipeRoute?> = .constant(nil)
    ) {
        self.tab = tab
        self.dependencies = dependencies
        self._pendingDeepLink = pendingDeepLink
        self._externalRoute = externalRoute
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
        .onChange(of: externalRoute) { _, newValue in
            // App-Intents / Spotlight route push.
            guard let newValue else { return }
            path.append(newValue)
            externalRoute = nil
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        switch tab {
        case .feed:
            FeedView(
                viewModel: FeedViewModel(dependencies: dependencies.feedDependencies()),
                onSelect: { item in path.append(.recipe(item: item)) }
            )
        case .categories:
            CategoryListView(
                viewModel: CategoryListViewModel(dependencies: dependencies.categoriesDependencies()),
                onSelect: { category in path.append(.category(category)) }
            )
        case .search:
            SearchView(
                viewModel: SearchViewModel(dependencies: dependencies.searchDependencies()),
                onSelect: { item in path.append(.recipe(item: item)) }
            )
        case .saved:
            SavedView(
                viewModel: SavedViewModel(dependencies: dependencies.savedDependencies()),
                onSelect: { recipe in path.append(.recipe(item: Self.listItem(from: recipe))) }
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
                onSelect: { item in path.append(.recipe(item: item)) }
            )
            .onAppear {
                Telemetry.shared.send(.screenView(name: "category_recipes"))
            }
        }
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
        case .recipe(let id):
            if let cached = await cachedListItem(forID: id) {
                path = [.recipe(item: cached)]
            } else if let snapshotItem = snapshotListItem(forID: id) {
                path = [.recipe(item: snapshotItem)]
            }
        case .feed:
            // Already on Feed (RootView set the tab); just clear any push
            // stack so the user lands on the root list.
            path = []
        case .saved:
            // RootView routes `.saved` directly to the Saved tab and
            // never sets `pendingDeepLink`, so this branch is unreachable
            // in practice. Kept exhaustive so the compiler catches any
            // future caller that does forward the link through here.
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
