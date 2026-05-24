import DODAnalytics
import DODDesignSystem
import DODDomain
import DODFeatureCategories
import DODFeatureFeed
import DODFeatureRecipeDetail
import DODFeatureSaved
import DODFeatureSearch
import SwiftUI

/// Top-level shell. TabView on compact widths (iPhone, iPad split slide-over),
/// NavigationSplitView on iPad regular (T-142).
struct RootView: View {

    @State private var dependencies: AppDependencies
    @State private var selectedTab: AppTab = .feed
    @State private var feedPath: [RecipeRoute] = []
    @State private var categoriesPath: [RecipeRoute] = []
    @State private var searchPath: [RecipeRoute] = []
    @State private var savedPath: [RecipeRoute] = []
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(dependencies: AppDependencies) {
        _dependencies = State(initialValue: dependencies)
    }

    private func pathBinding(for tab: AppTab) -> Binding<[RecipeRoute]> {
        switch tab {
        case .feed: $feedPath
        case .categories: $categoriesPath
        case .search: $searchPath
        case .saved: $savedPath
        }
    }

    private func append(_ route: RecipeRoute, to tab: AppTab) {
        switch tab {
        case .feed: feedPath.append(route)
        case .categories: categoriesPath.append(route)
        case .search: searchPath.append(route)
        case .saved: savedPath.append(route)
        }
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadSplit
            } else {
                phoneTabs
            }
        }
        .task { await dependencies.bootstrap() }
    }

    // MARK: - iPhone (TabView)

    private var phoneTabs: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack(path: pathBinding(for: tab)) {
                    rootContent(for: tab)
                        .navigationDestination(for: RecipeRoute.self) { route in
                            destination(for: route, currentTab: tab)
                        }
                }
                .tabItem {
                    Label(tab.title, systemImage: tab.systemImage)
                }
                .tag(tab)
            }
        }
        .tint(DODColor.accent)
        .onChange(of: selectedTab) { _, newValue in
            Telemetry.shared.send(.screenView(name: newValue.telemetryName))
        }
        .onAppear {
            Telemetry.shared.send(.screenView(name: AppTab.feed.telemetryName))
        }
    }

    // MARK: - iPad (NavigationSplitView)

    private var iPadSplit: some View {
        let selectionBinding = Binding<AppTab?>(
            get: { selectedTab },
            set: { selectedTab = $0 ?? selectedTab }
        )
        return NavigationSplitView {
            List(selection: selectionBinding) {
                ForEach(AppTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.systemImage)
                        .tag(tab)
                }
            }
            .navigationTitle("DOD")
            .listStyle(.sidebar)
        } detail: {
            NavigationStack(path: pathBinding(for: selectedTab)) {
                rootContent(for: selectedTab)
                    .navigationDestination(for: RecipeRoute.self) { route in
                        destination(for: route, currentTab: selectedTab)
                    }
            }
        }
        .tint(DODColor.accent)
        .onChange(of: selectedTab) { _, newValue in
            Telemetry.shared.send(.screenView(name: newValue.telemetryName))
        }
    }

    // MARK: - Per-tab root

    @ViewBuilder
    private func rootContent(for tab: AppTab) -> some View {
        switch tab {
        case .feed:
            FeedView(
                viewModel: FeedViewModel(dependencies: dependencies.feedDependencies()),
                onSelect: { item in append(.recipe(item: item), to: tab) }
            )
        case .categories:
            CategoryListView(
                viewModel: CategoryListViewModel(dependencies: dependencies.categoriesDependencies()),
                onSelect: { category in append(.category(category), to: tab) }
            )
        case .search:
            SearchView(
                viewModel: SearchViewModel(dependencies: dependencies.searchDependencies()),
                onSelect: { item in append(.recipe(item: item), to: tab) }
            )
        case .saved:
            SavedView(
                viewModel: SavedViewModel(dependencies: dependencies.savedDependencies()),
                onSelect: { recipe in
                    append(.recipe(item: Self.listItem(from: recipe)), to: tab)
                }
            )
        }
    }

    // MARK: - Navigation destinations

    @ViewBuilder
    private func destination(for route: RecipeRoute, currentTab tab: AppTab) -> some View {
        switch route {
        case .recipe(let item):
            let canonical =
                item.canonicalURL
                ?? URL(string: "https://www.dutchovendaddy.com/") ?? URL(filePath: "/")
            RecipeDetailView(
                viewModel: RecipeDetailViewModel(
                    listItem: item,
                    canonicalURL: canonical,
                    dependencies: dependencies.recipeDetailDependencies()
                ),
                onSelectRelated: { related in
                    append(.recipe(item: related), to: tab)
                }
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
                onSelect: { item in append(.recipe(item: item), to: tab) }
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
            totalTimeDisplay: nil
        )
    }
}
