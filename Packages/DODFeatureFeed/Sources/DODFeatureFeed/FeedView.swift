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
    /// US-38 / AC-38.2 / CL-64 (T-650, 2026-05-27) — shared with `SearchView`
    /// via the same `@AppStorage` key. Default `.gallery` preserves CC-9's
    /// 2-column grid byte-for-byte for users who never tap the toggle.
    @AppStorage(RecipeListLayout.storageKey) private var layoutRaw: String =
        RecipeListLayout.gallery.rawValue
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
    /// US-41 / AC-41.1 — authorization seam forwarded into `SettingsView`'s
    /// `SettingsViewModel` so flipping the notifications toggle ON requests
    /// system permission. Optional; `nil` means the toggle persists intent
    /// but reports "not granted" (previews / tests). Production (TabStack)
    /// passes a closure that calls `NotificationService.requestAuthorization()`.
    public let onRequestNotificationAuthorization: (@MainActor () async -> Bool)?
    /// US-41 / AC-41.6 — fires the two sample local notifications behind
    /// the temporary DEBUG test affordance in `SettingsView`. Optional;
    /// production (TabStack) routes it through `NotificationService`.
    public let onSimulateNewPosts: (() -> Void)?

    public init(
        viewModel: FeedViewModel,
        onSelect: @escaping (RecipeListItem) -> Void,
        onSave: ((RecipeListItem) -> Void)? = nil,
        onClearImageCache: (() async throws -> Int)? = nil,
        onRequestNotificationAuthorization: (@MainActor () async -> Bool)? = nil,
        onSimulateNewPosts: (() -> Void)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onSelect = onSelect
        self.onSave = onSave
        self.onClearImageCache = onClearImageCache
        self.onRequestNotificationAuthorization = onRequestNotificationAuthorization
        self.onSimulateNewPosts = onSimulateNewPosts
    }

    public var body: some View {
        ZStack(alignment: .top) {
            content
            OfflineBanner(isOffline: viewModel.isOffline)
        }
        .background(DODColor.surface)
        // US-37 / AC-37.1 (T-640, 2026-05-27): "Recipes" → "Recipes & Articles".
        // Communicates that the tab surfaces both recipes (the JSON-LD-parseable
        // posts) and articles (the JSON-LD-less posts routed to ArticleDetailView
        // per CL-63). Matches AppTab.title for the same case. The bottom-tab
        // label is set independently in AppTab.title; this only drives the
        // screen's nav-bar title.
        .navigationTitle("Recipes & Articles")
        .toolbar {
            // US-38 / AC-38.1 / CL-64.5 (T-650): layout toggle declared
            // BEFORE the gear so the gear stays at the absolute trailing
            // edge — SwiftUI orders multiple ToolbarItems in the same
            // group from leading to trailing in declaration order.
            // US-32 AC-32.1: gear icon on the trailing edge of the Recipes
            // nav bar pushes the Settings page. NavigationLink lives in the
            // toolbar so it inherits the standard back button on the pushed
            // screen; the existing TabStack NavigationStack hosts the push.
            // `.topBarTrailing` is iOS-only; macOS test slice falls back to
            // the default `.automatic` placement so the package still builds.
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                layoutToggleToolbarButton
            }
            ToolbarItem(placement: .topBarTrailing) {
                settingsToolbarLink
            }
            #else
            ToolbarItem(placement: .automatic) {
                layoutToggleToolbarButton
            }
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
            SettingsView(
                viewModel: SettingsViewModel(
                    requestNotificationAuthorization: onRequestNotificationAuthorization ?? { false }
                ),
                onClearImageCache: onClearImageCache,
                onSimulateNewPosts: onSimulateNewPosts
            )
        } label: {
            Image(systemName: "gearshape")
                .accessibilityLabel("Settings")
        }
        .accessibilityIdentifier("feed-toolbar-settings")
    }

    /// US-38 / AC-38.1 / CL-64 (T-650): the layout-toggle button. Sits to
    /// the leading side of the gear icon in the trailing-edge toolbar
    /// group. Per CL-64.1 the icon shows the CURRENT layout (opposite
    /// of the typical iOS destination convention) — VoiceOver users
    /// hear the destination via the action hint so the affordance is
    /// still discoverable.
    private var layoutToggleToolbarButton: some View {
        let layout = RecipeListLayout(rawValue: layoutRaw) ?? .gallery
        return Button {
            var next = layout
            next.toggle()
            layoutRaw = next.rawValue
        } label: {
            Image(systemName: layout.toggleIconName)
                .accessibilityLabel(layout.currentStateAccessibilityLabel)
                .accessibilityHint(layout.destinationActionHint)
        }
        .accessibilityIdentifier("feed-toolbar-layout-toggle")
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
        // US-38 / AC-38.3 / AC-38.4 (T-650): branch on the persisted
        // layout. `.gallery` keeps the existing 2-col `LazyVGrid` body
        // byte-identical (CC-9 contract preserved); `.list` renders a
        // `LazyVStack` of `RecipeCard.ListRow` rows for denser scanning.
        let layout = RecipeListLayout(rawValue: layoutRaw) ?? .gallery
        return ScrollView {
            Group {
                switch layout {
                case .gallery:
                    galleryContent
                case .list:
                    listContent
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

    /// US-38 / AC-38.3 — the existing 2-col `LazyVGrid` rendering. Body
    /// byte-identical to the pre-T-650 `list` implementation; CC-9's grid
    /// contract is preserved unchanged.
    private var galleryContent: some View {
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
    }

    /// US-38 / AC-38.4 — the new denser single-column variant. Composes
    /// the same `recipeCardTap` + `recipeCardContextMenu` modifiers as
    /// the gallery so tap-to-open + long-press-Save (AC-34.1) work
    /// identically on both layouts.
    private var listContent: some View {
        LazyVStack(spacing: DODSpacing.xs) {
            ForEach(viewModel.items) { item in
                RecipeCard.ListRow(
                    title: item.title,
                    excerpt: item.excerpt,
                    heroImageURL: item.heroImage,
                    totalTimeDisplay: item.totalTimeDisplay
                )
                .recipeCardTap { onSelect(item) }
                .recipeCardContextMenu { onSave?(item) }
                .task {
                    await viewModel.loadMoreIfNeeded(currentItem: item)
                }
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
