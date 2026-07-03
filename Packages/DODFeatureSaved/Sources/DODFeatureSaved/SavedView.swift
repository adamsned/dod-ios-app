import DODDesignSystem
import DODDomain
import SwiftUI

public struct SavedView: View {

    @State private var viewModel: SavedViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// DUT-530 — the unified list/grid preference shared with Feed + Search via
    /// the same `@AppStorage` key (set from Settings ▸ Customization). Saved was
    /// hardcoded to the grid; it now branches like the other tabs. Default
    /// `.gallery` keeps the existing 2-col grid byte-identical for users who
    /// never toggle. Mirrors `FeedView`'s declaration.
    @AppStorage(RecipeListLayout.storageKey) private var layoutRaw: String =
        RecipeListLayout.gallery.rawValue
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

    /// US-39 / AC-39.3 — drives the "Make Shopping List" cart entry. DUT-487 /
    /// T-906 — the cart now opens ``ShoppingListView`` empty-first (was a
    /// builder-sheet-first path); the recipe picker lives inside that view. Non-nil
    /// pushes the (empty) shopping list onto the navigation stack; the pushed view
    /// carries the saved recipes so its own picker can build / append in place.
    @State private var shoppingListEntry: ShoppingListSelection?

    /// DUT-480 — external trigger for the iOS 18 Control Center control's
    /// `dod://shopping-list` deep link. `RootView` mints a fresh `UUID` when the
    /// control is tapped; each new value pushes the Shopping List empty-first
    /// (same push the header cart does), even on a repeat tap. `nil`/unchanged
    /// does nothing. Defaulted to a constant `nil` so the Saved-tab snapshot
    /// tests and the other tabs' call sites are unaffected.
    @Binding private var openShoppingListToken: UUID?

    public init(
        viewModel: SavedViewModel,
        openShoppingListToken: Binding<UUID?> = .constant(nil),
        onSelect: @escaping (Recipe) -> Void,
        onSave: ((Recipe) -> Void)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        _openShoppingListToken = openShoppingListToken
        self.onSelect = onSelect
        self.onSave = onSave
    }

    public var body: some View {
        // DUT-275 — the "Saved" title + cart are a pinned header row (nav bar
        // hidden), so the title sits at the same Y as every other tab in every
        // state. (No native `.navigationTitle` — dodges the iOS 26 large-title bug.)
        content
            .background(DODColor.surface)
            // DUT-275 — nav bar hidden; the cart lives in the header row above.
            .dodHidesNavBar()
            // DUT-487 / T-906 — push the Shopping List empty-first. The picker
            // now lives inside ``ShoppingListView``; the saved recipes ride along
            // so its "Build List" / "Add recipes" affordances can build in place.
            .navigationDestination(item: $shoppingListEntry) { selection in
                ShoppingListView(
                    viewModel: ShoppingListViewModel(),
                    recipes: selection.recipes,
                    // DUT-487 — hydrate each picked recipe's ingredients before
                    // the Shopping List builds rows. Saved recipes often arrive
                    // with empty `ingredients` (detail never fetched), which
                    // produced ZERO rows; this fetches + parses + caches on demand.
                    // Covers the deep-link path too — it drives this same
                    // destination (`shoppingListEntry`).
                    hydrate: { await viewModel.recipeWithIngredients($0) }
                )
            }
            // DUT-480 — the iOS 18 Control Center control's `dod://shopping-list`
            // deep link. `.task(id:)` (not `.onChange`) so a token already set
            // when this tab is first instantiated (cold launch straight from the
            // control) is still consumed. Opens the Shopping List empty-first,
            // carrying the saved recipes so its picker can build in place — the
            // same push the header cart does.
            .task(id: openShoppingListToken) {
                guard openShoppingListToken != nil else { return }
                shoppingListEntry = ShoppingListSelection(recipes: viewModel.recipes)
                openShoppingListToken = nil
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

    @ViewBuilder
    private var content: some View {
        // DUT-275 — the "Saved" title + its cart button share one header row at
        // the very top (nav bar hidden), so the title sits at the same Y as every
        // other tab in every state. The grid scrolls beneath the pinned title.
        VStack(spacing: 0) {
            DODScreenHeader("Saved") {
                // AC-39.3 / CL-85 — the "Make Shopping List" cart, in the header
                // row (was a nav-bar toolbar item). Only in `.loaded` (nothing to
                // build a list from otherwise), mirroring the hide-when-empty rule.
                if viewModel.loadState == .loaded {
                    Button {
                        shoppingListEntry = ShoppingListSelection(recipes: viewModel.recipes)
                    } label: {
                        Image(systemName: "cart")
                            .accessibilityLabel("Make Shopping List")
                    }
                    .tint(DODColor.burntOrange)
                    .accessibilityIdentifier("saved-make-shopping-list")
                }
            }
            loadStateBody
        }
    }

    @ViewBuilder
    private var loadStateBody: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            EmptyState(
                systemImage: "bookmark",
                title: "No saved recipes yet",
                message: "Tap the bookmark on any recipe to find it again later."
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error:
            EmptyState(
                systemImage: "exclamationmark.triangle",
                title: "Couldn't load saved recipes",
                message: "Try again in a moment.",
                action: .init(title: "Retry") {
                    Task { await viewModel.refresh() }
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded:
            // DUT-530 — branch on the unified list/grid preference (shared with
            // Feed + Search via the same `@AppStorage` key). `.gallery` keeps the
            // existing 2-col `LazyVGrid`; `.list` renders `RecipeCard.ListRow`s
            // via `adaptiveListRows`, mirroring `FeedView.listContent`.
            let layout = RecipeListLayout(rawValue: layoutRaw) ?? .gallery
            ScrollView {
                Group {
                    switch layout {
                    case .gallery:
                        galleryContent
                    case .list:
                        listContent
                    }
                }
                .padding(.horizontal, DODSpacing.md)
                .padding(.vertical, DODSpacing.md)
            }
        }
    }

    /// DUT-530 — the existing 2-col `LazyVGrid` of `RecipeCard`s, unchanged
    /// (only lifted out of `loadStateBody` so `.loaded` can branch on layout).
    /// `.gallery` keeps the Saved grid byte-identical to the pre-DUT-530 render.
    private var galleryContent: some View {
        LazyVGrid(
            columns: recipeGridColumns(horizontalSizeClass: horizontalSizeClass),
            spacing: DODSpacing.md
        ) {
            ForEach(viewModel.recipes) { recipe in
                RecipeCard(
                    title: recipe.title,
                    excerpt: recipe.excerpt,
                    heroImageURL: recipe.heroImage,
                    // CL-255 — cook-time chip omitted (browse declutter);
                    // time is on the recipe detail page + Search's filter.
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
    }

    /// DUT-530 — the dense single-column variant, mirroring
    /// `FeedView.listContent`: `adaptiveListRows` (iPad tiles the rows into a
    /// multi-column grid, iPhone keeps the single-column stack) of
    /// `RecipeCard.ListRow`s. Preserves Saved's context-menu args verbatim
    /// (`isSaved: true`, the downloaded check, the optimistic-remove +
    /// remove-download handlers) so long-press Save/Unsave + Remove Download
    /// work identically to the gallery. The row carries the real `isDownloaded`
    /// so the compact download glyph (DUT-530) matches the gallery card's badge.
    private var listContent: some View {
        adaptiveListRows(horizontalSizeClass: horizontalSizeClass) {
            ForEach(viewModel.recipes) { recipe in
                RecipeCard.ListRow(
                    title: recipe.title,
                    excerpt: recipe.excerpt,
                    heroImageURL: recipe.heroImage,
                    // T-774 / DUT-80 — same "saved AND downloaded" badge the
                    // gallery card shows, in the row's compact glyph form.
                    isDownloaded: viewModel.downloadedIDs.contains(recipe.id)
                )
                .recipeCardTap { onSelect(recipe) }
                .accessibilityIdentifier("dod.saved.card")
                .recipeCardContextMenu(
                    isSaved: true,
                    isDownloaded: viewModel.downloadedIDs.contains(recipe.id),
                    onToggle: {
                        viewModel.optimisticallyRemove(id: recipe.id)
                        onSave?(recipe)
                    },
                    onRemoveDownload: {
                        Task { await viewModel.requestRemoveDownload(id: recipe.id) }
                    }
                )
            }
        }
    }
}

// MARK: - Shopping-list navigation payload

/// Wraps the saved recipes handed to the pushed ``ShoppingListView`` so
/// `navigationDestination(item:)` can key on it (US-39 / AC-39.3 → AC-39.4).
/// DUT-487 / T-906 — this now carries the *pickable* recipes (the list opens
/// empty and builds in place), not a pre-built selection. Identity is a fresh
/// `UUID` per tap so re-entering pushes a new (empty) list. The `recipes` order
/// matches the Saved tab's source order (CL-77 per-recipe rows).
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
