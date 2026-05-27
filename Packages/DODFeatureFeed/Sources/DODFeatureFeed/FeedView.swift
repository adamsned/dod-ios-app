import DODDesignSystem
import DODDomain
import SwiftUI

/// Home feed screen. Pull-to-refresh + infinite scroll + offline banner +
/// first-launch-offline empty state.
///
/// Tapping a row is broadcast via `onSelect` so the app composition root
/// can navigate without this module knowing about the detail feature.
public struct FeedView: View {

    @State private var viewModel: FeedViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    public let onSelect: (RecipeListItem) -> Void

    public init(viewModel: FeedViewModel, onSelect: @escaping (RecipeListItem) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSelect = onSelect
    }

    public var body: some View {
        ZStack(alignment: .top) {
            content
            OfflineBanner(isOffline: viewModel.isOffline)
        }
        .background(DODColor.surface)
        .navigationTitle("Recipes")
        .toolbar {
            // US-32 AC-32.1: gear icon on the trailing edge of the Recipes
            // nav bar pushes the Settings page. NavigationLink lives in the
            // toolbar so it inherits the standard back button on the pushed
            // screen; the existing TabStack NavigationStack hosts the push.
            // `.topBarTrailing` is iOS-only; macOS test slice falls back to
            // the default `.automatic` placement so the package still builds.
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                settingsToolbarLink
            }
            #else
            ToolbarItem(placement: .automatic) {
                settingsToolbarLink
            }
            #endif
        }
        .task { await viewModel.onAppear() }
        .refreshable { await viewModel.refresh() }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isOffline)
        .sensoryFeedback(.success, trigger: viewModel.refreshCount)
    }

    /// The toolbar gear-icon NavigationLink (US-32 AC-32.1). Extracted so
    /// the `#if os(iOS)` placement branch + the macOS fallback share one
    /// label definition.
    private var settingsToolbarLink: some View {
        NavigationLink {
            SettingsView()
        } label: {
            Image(systemName: "gearshape")
                .accessibilityLabel("Settings")
        }
        .accessibilityIdentifier("feed-toolbar-settings")
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .loadingInitial:
            loadingSkeletons
        case .firstLaunchOffline:
            EmptyState(
                systemImage: "wifi.slash",
                title: "You need internet",
                message: "Connect to load recipes the first time.",
                action: .init(title: "Retry") {
                    Task { await viewModel.refresh() }
                }
            )
        case .empty:
            EmptyState(
                systemImage: "tray",
                title: "No recipes",
                message: "Check back soon."
            )
        case .idle, .loaded, .loadingMore:
            list
        }
    }

    private var list: some View {
        ScrollView {
            LazyVGrid(columns: recipeGridColumns(horizontalSizeClass: horizontalSizeClass), spacing: DODSpacing.md) {
                ForEach(viewModel.items) { item in
                    FeedRow(item: item)
                        .recipeCardTap { onSelect(item) }
                        .task {
                            await viewModel.loadMoreIfNeeded(currentItem: item)
                        }
                }
            }
            .padding(.horizontal, DODSpacing.md)
            .padding(.top, viewModel.isOffline ? DODSpacing.xl : DODSpacing.md)

            if viewModel.loadState == .loadingMore {
                ProgressView()
                    .padding(.vertical, DODSpacing.lg)
            }
        }
    }

    private var loadingSkeletons: some View {
        ScrollView {
            VStack(spacing: DODSpacing.md) {
                ForEach(0..<6, id: \.self) { _ in
                    LoadingSkeleton(cornerRadius: DODSpacing.sm)
                        .frame(height: 280)
                }
            }
            .padding(DODSpacing.md)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Loading recipes")
        }
    }
}
