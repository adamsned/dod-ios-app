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
    ///
    /// DUT-629 — the closure reports the store write's success via a completion
    /// (`@MainActor (Bool) -> Void`). The card is removed optimistically before
    /// the call; a `false` completion means the write failed, so the view
    /// re-refreshes to restore the row that was wrongly removed.
    public let onSave: ((Recipe, @escaping @MainActor (Bool) -> Void) -> Void)?
    /// DUT-551 (CL-306) — opens the Settings sheet from the header's trailing
    /// gear (Settings left the tab bar; the gear now lives on every main tab).
    /// Optional + default nil so existing callers / previews / snapshots show no
    /// gear and stay unaffected. Production wires it through `TabStack`.
    public let onOpenSettings: (() -> Void)?

    public init(
        viewModel: SavedViewModel,
        onSelect: @escaping (Recipe) -> Void,
        onSave: ((Recipe, @escaping @MainActor (Bool) -> Void) -> Void)? = nil,
        onOpenSettings: (() -> Void)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onSelect = onSelect
        self.onSave = onSave
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        // DUT-275 — the "Saved" title is a pinned header row (nav bar hidden), so
        // it sits at the same Y as every other tab in every state. (No native
        // `.navigationTitle` — dodges the iOS 26 large-title bug.)
        content
            .background(DODColor.surface)
            // DUT-275 — nav bar hidden; the pinned header lives above.
            .dodHidesNavBar()
            .task {
                // DUT-6: subscribe to CloudKit remote-import signals (no-op
                // if already subscribed) so a recipe saved on another device
                // surfaces here without a relaunch, then do the appear-time
                // fetch. The subscription outlives this `.task`; the
                // debounced re-fetch reconciles on each remote import.
                viewModel.startObserving()
                await viewModel.refresh()
            }
    }

    @ViewBuilder
    private var content: some View {
        // DUT-275 — the "Saved" title is pinned at the very top (nav bar hidden),
        // so it sits at the same Y as every other tab in every state. The grid
        // scrolls beneath the pinned title. DUT-536 — the "Make Shopping List"
        // cart that used to sit on this row was removed now that the top-level
        // Grocery List tab is the single store-backed list surface, so this is a
        // title-only header matching Search/Settings.
        VStack(spacing: 0) {
            // DUT-551 (CL-306) — Settings gear in the trailing slot when wired.
            DODScreenHeader("Saved") {
                // DUT-572 — gear only in compact width (iPhone); iPad's sidebar
                // already has a Settings row, so it's redundant in regular width.
                if let onOpenSettings, horizontalSizeClass == .compact {
                    DODHeaderGearButton { onOpenSettings() }
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
                title: "No Saved Recipes Yet",
                message: "Tap the bookmark on any recipe to find it again later."
            )
            // Stable test handle for the L5 E2E empty-state assertions —
            // decoupled from the visible title so the CL-305 Title Case copy
            // change ("No saved recipes yet" → "No Saved Recipes Yet"), and any
            // future copy change, doesn't break the tests. `accessibilityIdentifier`
            // propagates to the descendant static texts, so they're queryable
            // via `app.staticTexts["saved.emptyState"]`.
            .accessibilityIdentifier("saved.emptyState")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error:
            EmptyState(
                systemImage: "exclamationmark.triangle",
                title: "Couldn't Load Saved Recipes",
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
            // DUT-693 — pull-to-refresh re-runs the same load the appear-time
            // `.task` does (Feed already has this), so a cross-device save/unsave
            // can be pulled in without waiting for the debounced remote-change
            // refresh or a tab switch.
            .refreshable { await viewModel.refresh() }
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
                        // DUT-700 PR-A — ease the grid reflow (default ~0.35s;
                        // an L5 test asserts the card is gone within 0.5s).
                        withAnimation { viewModel.optimisticallyRemove(id: recipe.id) }
                        // DUT-629 — restore the row if the store write failed.
                        onSave?(recipe) { didSave in
                            if !didSave {
                                // DUT-736: clear the optimistic-removal suppression
                                // FIRST — otherwise `refresh()` re-hides the still-
                                // saved card within the 2s `pendingRemovals` TTL and
                                // the restore is a silent no-op.
                                viewModel.clearPendingRemoval(id: recipe.id)
                                Task { await viewModel.refresh() }
                            }
                        }
                    },
                    onRemoveDownload: {
                        // T-775 / DUT-81 — un-download clears the badge
                        // optimistically (the card stays — un-download ≠
                        // unsave). DUT-229 — removal is instant online OR
                        // offline: it only clears the pin, leaving the saved
                        // recipe fully openable offline, so nothing is
                        // stranded and no confirmation is needed.
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
                        // DUT-700 PR-A — ease the list reflow (default ~0.35s;
                        // an L5 test asserts the card is gone within 0.5s).
                        withAnimation { viewModel.optimisticallyRemove(id: recipe.id) }
                        // DUT-629 — restore the row if the store write failed.
                        onSave?(recipe) { didSave in
                            if !didSave {
                                // DUT-736: clear the optimistic-removal suppression
                                // FIRST — otherwise `refresh()` re-hides the still-
                                // saved card within the 2s `pendingRemovals` TTL and
                                // the restore is a silent no-op.
                                viewModel.clearPendingRemoval(id: recipe.id)
                                Task { await viewModel.refresh() }
                            }
                        }
                    },
                    onRemoveDownload: {
                        Task { await viewModel.requestRemoveDownload(id: recipe.id) }
                    }
                )
            }
        }
    }
}
