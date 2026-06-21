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
    /// DUT-183 — presents the guided "Your First Cookout" flow as a sheet.
    @State private var showingFirstCookout = false
    public let onSelect: (RecipeListItem) -> Void
    /// US-34 / AC-34.1 — long-press → "Save" context menu wiring. Optional
    /// so existing callers (tests, previews) don't need to plumb it. nil
    /// here means the context menu still appears but the Save button is a
    /// no-op; production callers (TabStack) always pass a non-nil closure
    /// that routes through `RecipeStore.toggleSaved` per CL-59.
    public let onSave: ((RecipeListItem) -> Void)?

    public init(
        viewModel: FeedViewModel,
        onSelect: @escaping (RecipeListItem) -> Void,
        onSave: ((RecipeListItem) -> Void)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onSelect = onSelect
        self.onSave = onSave
    }

    public var body: some View {
        ZStack(alignment: .top) {
            content
            OfflineBanner(isOffline: viewModel.isOffline)
        }
        .background(DODColor.surface)
        // T-781 / DUT-87 — no `.navigationTitle`: the "Recipes & Articles" large
        // title is rendered as scrolling content (`DODScreenHeader` in `list`)
        // so it scrolls up and away instead of the native minimize, keeping every
        // tab's header behavior consistent (and dodging the iOS 26 large-title
        // bug). The `.toolbar` buttons below stay pinned in the nav bar.
        .toolbar {
            // DUT-183 — "Your First Cookout" entry on the leading edge (the
            // strategy's "Start Here"). `.topBarLeading` is iOS-only; the macOS
            // test slice falls back to `.automatic` so the package still builds.
            #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                firstCookoutToolbarButton
            }
            #else
            ToolbarItem(placement: .automatic) {
                firstCookoutToolbarButton
            }
            #endif
            // US-38 / AC-38.1 / CL-64.5 (T-650): layout toggle on the
            // trailing edge. The Settings gear that used to sit to its
            // trailing side (US-32 AC-32.1) moved to the shared
            // `SettingsToolbarModifier` applied by `TabStack` (DUT-26) so
            // every top-level tab carries the same gear at the absolute
            // trailing edge. Because `TabStack` applies that modifier AFTER
            // this view in the modifier chain, SwiftUI still orders the gear
            // to the trailing side of this toggle — the user-visible layout
            // (toggle then gear) is unchanged on Feed.
            // `.topBarTrailing` is iOS-only; macOS test slice falls back to
            // the default `.automatic` placement so the package still builds.
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                layoutToggleToolbarButton
            }
            #else
            ToolbarItem(placement: .automatic) {
                layoutToggleToolbarButton
            }
            #endif
        }
        .sheet(isPresented: $showingFirstCookout) {
            FirstCookoutView()
        }
        .task { await viewModel.onAppear() }
        .refreshable { await viewModel.refresh() }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isOffline)
        .sensoryFeedback(.success, trigger: viewModel.refreshCount)
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

    /// DUT-183 — the "Your First Cookout" entry: a flame on the leading edge
    /// that opens the guided first-cookout flow (the strategy's "Start Here").
    private var firstCookoutToolbarButton: some View {
        Button {
            showingFirstCookout = true
        } label: {
            Image(systemName: "flame.fill")
                .accessibilityLabel("Your First Cookout")
        }
        .tint(DODColor.burntOrange)
        .accessibilityIdentifier("feed-toolbar-first-cookout")
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
            // T-781 / DUT-87 — the title scrolls with the content (no native
            // minimize); offline shifts it below the OfflineBanner overlay.
            DODScreenHeader("Recipes & Articles")
                .padding(.top, viewModel.isOffline ? DODSpacing.xl : 0)
            Group {
                switch layout {
                case .gallery:
                    galleryContent
                case .list:
                    listContent
                }
            }
            .padding(.horizontal, DODSpacing.md)
            .padding(.top, DODSpacing.md)

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
                    // T-765 / CL-162 (DUT-71) — state-aware Save/Unsave from the
                    // viewmodel-owned saved-id set; optimistic flip on toggle.
                    .recipeCardContextMenu(isSaved: viewModel.savedRecipeIDs.contains(item.id)) {
                        viewModel.applyOptimisticSaveToggle(id: item.id)
                        onSave?(item)
                    }
                    // Stable L3 handle: `app.buttons.matching(identifier:)`
                    // targets feed recipe cards directly, so XCUITest can't
                    // accidentally tap a nav-bar toolbar button (the layout
                    // toggle / Settings gear) that the old "buttons NOT IN
                    // tab labels" query swept up. Mirrors `dod.saved.card`.
                    // Non-visual — does not affect L4 snapshots.
                    .accessibilityIdentifier("dod.feed.card")
                    .task {
                        await viewModel.loadMoreIfNeeded(currentItem: item)
                    }
            }
        }
    }

    /// US-38 / AC-38.4 — the new denser single-column variant. Composes
    /// the same `recipeCardTap` + `recipeCardContextMenu` modifiers as
    /// the gallery so tap-to-open + long-press-Save/Unsave (AC-34.1 /
    /// AC-34.6) work identically on both layouts.
    private var listContent: some View {
        // T-782 / DUT-88 — iPad tiles the dense rows into a multi-column grid;
        // iPhone (compact) keeps the exact single-column LazyVStack.
        adaptiveListRows(horizontalSizeClass: horizontalSizeClass) {
            ForEach(viewModel.items) { item in
                RecipeCard.ListRow(
                    title: item.title,
                    excerpt: item.excerpt,
                    heroImageURL: item.heroImage,
                    totalTimeDisplay: item.totalTimeDisplay
                )
                .recipeCardTap { onSelect(item) }
                .recipeCardContextMenu(isSaved: viewModel.savedRecipeIDs.contains(item.id)) {
                    viewModel.applyOptimisticSaveToggle(id: item.id)
                    onSave?(item)
                }
                .accessibilityIdentifier("dod.feed.card")
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
