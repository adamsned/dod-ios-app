import DODDesignSystem
import DODDomain
import SwiftUI

public struct SavedView: View {

    @State private var viewModel: SavedViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    public let onSelect: (Recipe) -> Void
    /// US-34 / AC-34.1 / AC-34.6 — long-press → state-aware Save/Unsave
    /// context menu wiring. See `FeedView.onSave`; this surface passes a
    /// `Recipe` (not a `RecipeListItem`) because the Saved tab already has
    /// the full domain type at hand. The closure is a toggle —
    /// `RecipeStore.toggleSaved(id:)` flips `isSaved` in both directions,
    /// so a "Save"/"Unsave" tap from the card's context menu routes to the
    /// same closure regardless of the current saved state. CL-103 (T-634)
    /// reversed CL-60's "no Unsave branch in v1" decision: the helper now
    /// renders "Unsave" + outline `bookmark` when `isSaved: true` (always
    /// the case here) and "Save" + `bookmark.fill` when `isSaved: false`
    /// (used by Feed/Categories/Search per their respective TODO markers).
    public let onSave: ((Recipe) -> Void)?

    /// US-39 / AC-39.3 / CL-85 — drives the "Make Shopping List" entry. When the
    /// builder sheet is presented this is `true`; the recipes the user picks
    /// land in ``builtListRecipes``, which pushes ``ShoppingListView``.
    @State private var isBuildingShoppingList = false
    /// The recipes the picker built a list from. Non-nil pushes the shopping
    /// list onto the navigation stack (AC-39.3 → AC-39.4 render). Wrapped so
    /// `navigationDestination(item:)` keys on it.
    @State private var builtListRecipes: ShoppingListSelection?

    public init(
        viewModel: SavedViewModel,
        onSelect: @escaping (Recipe) -> Void,
        onSave: ((Recipe) -> Void)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onSelect = onSelect
        self.onSave = onSave
    }

    public var body: some View {
        // T-781 / DUT-87 — the "Saved" title scrolls with the grid
        // (`DODScreenHeader` inside the loaded ScrollView), matching every other
        // tab; only the toolbar cart stays pinned. (T-776 had already dropped the
        // native `.navigationTitle` to dodge the iOS 26 large-title vanish bug.)
        content
            .background(DODColor.surface)
            .toolbar { shoppingListToolbar }
            // DUT-263 — the cart button only exists in `.loaded`; reserve the nav
            // bar in every state so the "Saved" title sits at the same height
            // across empty / loading / loaded (and matches Recipes).
            .dodReservesNavBarHeight()
            .sheet(isPresented: $isBuildingShoppingList) {
                ShoppingListBuilderSheet(recipes: viewModel.recipes) { selected in
                    builtListRecipes = ShoppingListSelection(recipes: selected)
                }
            }
            .navigationDestination(item: $builtListRecipes) { selection in
                ShoppingListView(viewModel: ShoppingListViewModel(recipes: selection.recipes))
            }
            .task {
                // DUT-6: subscribe to CloudKit remote-import signals (no-op
                // if already subscribed) so a recipe saved on another device
                // surfaces here without a relaunch, then do the appear-time
                // fetch. The subscription outlives this `.task`; the
                // debounced re-fetch reconciles on each remote import.
                viewModel.startObserving()
                await viewModel.refresh()
            }
            // DUT-84 — confirm before removing a download while offline. The
            // context-menu "Remove Download" routes through `requestRemoveDownload`,
            // which sets `pendingOfflineRemoveDownloadID` when there's no network.
            .offlineRemoveDownloadAlert(
                isPresented: Binding(
                    get: { viewModel.pendingOfflineRemoveDownloadID != nil },
                    set: { if !$0 { viewModel.cancelPendingRemoveDownload() } }
                ),
                onRemove: { Task { await viewModel.confirmPendingRemoveDownload() } }
            )
    }

    /// AC-39.3 / CL-85 decision 1 — the Saved-tab entry into the shopping-list
    /// flow. Rendered only in the `.loaded` state (there are no saved recipes
    /// to pick from otherwise, mirroring the AC-39.1 hide-when-empty posture).
    @ToolbarContentBuilder
    private var shoppingListToolbar: some ToolbarContent {
        if viewModel.loadState == .loaded {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isBuildingShoppingList = true
                } label: {
                    Label("Make Shopping List", systemImage: "cart")
                }
                .accessibilityIdentifier("saved-make-shopping-list")
                .accessibilityLabel("Make Shopping List")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            withSavedHeader {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .empty:
            withSavedHeader {
                EmptyState(
                    systemImage: "bookmark",
                    title: "No saved recipes yet",
                    message: "Tap the bookmark on any recipe to find it again later."
                )
            }
        case .error:
            withSavedHeader {
                EmptyState(
                    systemImage: "exclamationmark.triangle",
                    title: "Couldn't load saved recipes",
                    message: "Try again in a moment.",
                    action: .init(title: "Retry") {
                        Task { await viewModel.refresh() }
                    }
                )
            }
        case .loaded:
            ScrollView {
                DODScreenHeader("Saved")
                LazyVGrid(
                    columns: recipeGridColumns(horizontalSizeClass: horizontalSizeClass),
                    spacing: DODSpacing.md
                ) {
                    ForEach(viewModel.recipes) { recipe in
                        RecipeCard(
                            title: recipe.title,
                            excerpt: recipe.excerpt,
                            heroImageURL: recipe.heroImage,
                            totalTimeDisplay: totalTimeDisplay(recipe),
                            // T-774 / DUT-80 — badge the cards that are saved
                            // AND downloaded for offline use.
                            isDownloaded: viewModel.downloadedIDs.contains(recipe.id)
                        )
                        .recipeCardTap { onSelect(recipe) }
                        // T-638 / CL-107 — stable test handle for the L5 E2E
                        // `test_long_press_unsave_from_saved_tab` (long-presses
                        // the card → asserts the context menu reads "Unsave"
                        // not "Save" → taps Unsave → asserts the card is gone
                        // within 0.5s, the frame-tight window that catches a
                        // regression to non-optimistic removal — pins CL-104 /
                        // T-635 + REG-21). The identifier is applied AFTER
                        // `recipeCardTap` so it survives the
                        // `accessibilityElement(children: .combine)` consolidation
                        // that the tap modifier applies — the identifier
                        // attaches to the combined accessibility element,
                        // which is the element XCUITest queries via
                        // `app.buttons.matching(identifier:)`.
                        .accessibilityIdentifier("dod.saved.card")
                        // US-34 / AC-34.6 / CL-103 (T-634, 2026-05-29) —
                        // every card in the Saved tab is by definition
                        // saved (the source is `RecipeStore.savedRecipes()`),
                        // so `isSaved: true` is a constant here. The
                        // `onToggle` closure routes through the same
                        // `onSave?(recipe)` path; `RecipeStore.toggleSaved`
                        // flips in both directions, so tapping "Unsave"
                        // correctly transitions the row to `isSaved == false`.
                        .recipeCardContextMenu(
                            isSaved: true,
                            // T-775 / DUT-81 — surfaces "Remove Download" only
                            // for the saved cards that are also downloaded.
                            isDownloaded: viewModel.downloadedIDs.contains(recipe.id),
                            onToggle: {
                                // T-635 / CL-104 — optimistic local removal so
                                // the card disappears instantly; the store toggle
                                // bubbles through `TabStack.saveFromCard(...)`
                                // without a completion callback, so without this
                                // the row lingers until the next `.task` cycle
                                // (tab switch). Order matters: UI first, then
                                // persistence fires asynchronously.
                                viewModel.optimisticallyRemove(id: recipe.id)
                                onSave?(recipe)
                            },
                            onRemoveDownload: {
                                // T-775 / DUT-81 — un-download clears the badge
                                // optimistically (the card stays — un-download ≠
                                // unsave). DUT-84 — but offline, removal would
                                // strand the recipe, so route through
                                // `requestRemoveDownload`, which confirms first
                                // when there's no connection and removes
                                // immediately when online.
                                Task { await viewModel.requestRemoveDownload(id: recipe.id) }
                            }
                        )
                    }
                }
                .padding(.horizontal, DODSpacing.md)
                .padding(.vertical, DODSpacing.md)
            }
        }
    }

    /// DUT-263 — keeps the "Saved" title on screen in the non-loaded states
    /// (was: the header only existed inside the `.loaded` `ScrollView`, so the
    /// empty / error / loading screens had no title at all). The header pins to
    /// the top via `safeAreaInset` — at the same below-the-nav-bar height as the
    /// loaded grid's header — while the state content centers in the space below.
    private func withSavedHeader<Content: View>(
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .top, spacing: 0) {
                DODScreenHeader("Saved")
                    .background(DODColor.surface)
            }
    }

    private func totalTimeDisplay(_ recipe: Recipe) -> String? {
        guard let total = recipe.totalTime else { return nil }
        let seconds = Int(total.components.seconds)
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours) hr" : "\(hours)h \(remainder)m"
    }
}

// MARK: - Shopping-list navigation payload

/// Wraps the recipes the builder sheet selected so `navigationDestination(item:)`
/// can key on it (US-39 / AC-39.3 → AC-39.4). Identity is a fresh `UUID` per
/// build so re-building from the same recipes still pushes a new list. The
/// `recipes` order matches the picker's source order (CL-77 per-recipe rows).
struct ShoppingListSelection: Identifiable, Hashable {
    let id = UUID()
    let recipes: [Recipe]

    static func == (lhs: ShoppingListSelection, rhs: ShoppingListSelection) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
