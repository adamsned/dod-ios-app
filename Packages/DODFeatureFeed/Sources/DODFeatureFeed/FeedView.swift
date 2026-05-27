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
    /// US-34 / AC-34.1 — long-press → "Save" context menu wiring. Optional
    /// so existing callers (tests, previews) don't need to plumb it. nil
    /// here means the context menu still appears but the Save button is a
    /// no-op; production callers (TabStack) always pass a non-nil closure
    /// that routes through `RecipeStore.toggleSaved` per CL-59.
    public let onSave: ((RecipeListItem) -> Void)?
    /// US-36 / AC-36.4 — Clear Cached Recipe Images closure plumbed from
    /// the composition root through the gear-icon NavigationLink into
    /// `SettingsView`. Optional so existing callers (tests, previews)
    /// don't need to plumb it. Production callers (TabStack) always
    /// pass a non-nil closure that routes through
    /// `RecipeStore.clearImageCache()` and returns freed-byte total.
    public let onClearImageCache: (() async throws -> Int)?

    public init(
        viewModel: FeedViewModel,
        onSelect: @escaping (RecipeListItem) -> Void,
        onSave: ((RecipeListItem) -> Void)? = nil,
        onClearImageCache: (() async throws -> Int)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onSelect = onSelect
        self.onSave = onSave
        self.onClearImageCache = onClearImageCache
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
    /// label definition. The `onClearImageCache` closure (US-36 / AC-36.4)
    /// is forwarded into `SettingsView` so the Clear Cache row's tap
    /// routes through the composition root's `RecipeStore` instance.
    private var settingsToolbarLink: some View {
        NavigationLink {
            SettingsView(onClearImageCache: onClearImageCache)
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
                        .recipeCardContextMenu { onSave?(item) }
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
