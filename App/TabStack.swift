import DODAnalytics
import DODDesignSystem
import DODDomain
import DODFeatureCategories
import DODFeatureFeed
import DODFeatureRecipeDetail
import DODFeatureSaved
import DODFeatureSearch
import SwiftUI

/// One tab's navigation stack. Each tab gets its own `@State` path so
/// SwiftUI's binding identity stays stable across re-renders of the host
/// TabView — moving the @State out of the parent was the fix for DOD-NAV-1.
struct TabStack: View {

    let tab: AppTab
    let dependencies: AppDependencies
    /// Binding-style sink so RootView can drive a tab's stack from outside —
    /// used by App Intents / Spotlight deep links (US-10). Optional so the
    /// non-feed stacks don't need to plumb anything.
    @Binding var externalRoute: RecipeRoute?
    @State private var path: [RecipeRoute] = []

    init(
        tab: AppTab,
        dependencies: AppDependencies,
        externalRoute: Binding<RecipeRoute?> = .constant(nil)
    ) {
        self.tab = tab
        self.dependencies = dependencies
        self._externalRoute = externalRoute
    }

    var body: some View {
        NavigationStack(path: $path) {
            rootContent
                .navigationDestination(for: RecipeRoute.self) { route in
                    destination(for: route)
                }
        }
        .onChange(of: externalRoute) { _, newValue in
            guard let newValue else { return }
            path.append(newValue)
            // Hand the binding back so RootView can detect that the push has
            // landed and clear `pending` on DeepLinkDispatcher.
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
}
