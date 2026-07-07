import DODDesignSystem
import DODDomain
import SwiftUI

public struct CategoryRecipesView: View {

    @State private var viewModel: CategoryRecipesViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    // DUT-531 — the unified list/grid preference shared with Feed / Saved /
    // Search (Settings ▸ Customization). Category browsing branches on it too.
    @AppStorage(RecipeListLayout.storageKey) private var layoutRaw: String =
        RecipeListLayout.gallery.rawValue
    public let onSelect: (RecipeListItem) -> Void
    /// US-34 / AC-34.1 — long-press → "Save" context menu wiring. See
    /// `FeedView.onSave` for the contract (incl. the DUT-629 success completion);
    /// same shape applied to category recipe lists.
    public let onSave: ((RecipeListItem, @escaping @MainActor (Bool) -> Void) -> Void)?

    public init(
        viewModel: CategoryRecipesViewModel,
        onSelect: @escaping (RecipeListItem) -> Void,
        onSave: ((RecipeListItem, @escaping @MainActor (Bool) -> Void) -> Void)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onSelect = onSelect
        self.onSave = onSave
    }

    public var body: some View {
        content
            .background(DODColor.surface)
            .navigationTitle(viewModel.category.name)
            .task { await viewModel.onAppear() }
            // DUT-693 (PR6) — haptics parity with Feed. A `.success` tap on a
            // clean pull-to-refresh / retry (see `refreshCount`), and a
            // `.selection` tap whenever the saved-id set flips from a card
            // long-press Save/Unsave (mirrors the Feed's sensoryFeedback wiring).
            .sensoryFeedback(.success, trigger: viewModel.refreshCount)
            .sensoryFeedback(.selection, trigger: viewModel.savedRecipeIDs)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .idle, .loadingInitial:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error:
            EmptyState(
                systemImage: "exclamationmark.triangle",
                title: "Couldn't load",
                message: "Tap retry to try again.",
                action: .init(title: "Retry") {
                    Task { await viewModel.retry() }
                }
            )
        case .offline:
            // DUT-695 — a connectivity failure on the initial load gets a
            // "reconnect" hint (mirrors Search's `.offline` copy tone) rather
            // than the generic "Couldn't load". Retry re-runs the same load.
            EmptyState(
                systemImage: "wifi.slash",
                title: "No Internet Connection",
                message: "Reconnect to browse dutchovendaddy.com.",
                action: .init(title: "Retry") {
                    Task { await viewModel.retry() }
                }
            )
            .accessibilityIdentifier("dod.category.offlineState")
        case .empty:
            EmptyState(
                systemImage: "tray",
                title: "No recipes here",
                message: "Try a different category."
            )
        case .loaded, .loadingMore:
            // DUT-531 — `.gallery` keeps the 2-col `LazyVGrid` of `RecipeCard`;
            // `.list` renders `RecipeCard.ListRow`s via `adaptiveListRows`,
            // mirroring `FeedView` / `SavedView`.
            let layout = RecipeListLayout(rawValue: layoutRaw) ?? .gallery
            ScrollView {
                Group {
                    switch layout {
                    case .gallery:
                        LazyVGrid(
                            columns: recipeGridColumns(horizontalSizeClass: horizontalSizeClass),
                            spacing: DODSpacing.md
                        ) {
                            ForEach(viewModel.items) { item in
                                recipeCard(item)
                            }
                        }
                    case .list:
                        adaptiveListRows(horizontalSizeClass: horizontalSizeClass) {
                            ForEach(viewModel.items) { item in
                                recipeListRow(item)
                            }
                        }
                    }
                }
                .padding(DODSpacing.md)

                if viewModel.loadState == .loadingMore {
                    ProgressView()
                        .padding(.vertical, DODSpacing.lg)
                }
            }
            // DUT-693 (PR6) — pull-to-refresh parity with Feed / Saved. Reloads
            // page 1 without breaking the DUT load-more pagination.
            .refreshable { await viewModel.refresh() }
        }
    }

    // CL-255 — cook-time chip omitted (browse declutter); time is on the
    // recipe detail page + Search's time filter.
    private func recipeCard(_ item: RecipeListItem) -> some View {
        decorate(
            RecipeCard(
                title: item.title,
                excerpt: item.excerpt,
                heroImageURL: item.heroImage
            ),
            item
        )
    }

    private func recipeListRow(_ item: RecipeListItem) -> some View {
        decorate(
            RecipeCard.ListRow(
                title: item.title,
                excerpt: item.excerpt,
                heroImageURL: item.heroImage
            ),
            item
        )
    }

    // DUT-531 — the gallery card + list row share the same tap / save
    // context-menu / accessibility id / pagination trigger.
    private func decorate(_ card: some View, _ item: RecipeListItem) -> some View {
        card
            .recipeCardTap { onSelect(item) }
            // T-765 / CL-162 (DUT-71) — state-aware Save/Unsave from the
            // viewmodel-owned saved-id set; optimistic flip on toggle.
            .recipeCardContextMenu(isSaved: viewModel.savedRecipeIDs.contains(item.id)) {
                // DUT-629 — optimistic flip, re-inverted on write failure.
                viewModel.applyOptimisticSaveToggle(id: item.id)
                onSave?(item) { didSave in
                    if !didSave { viewModel.applyOptimisticSaveToggle(id: item.id) }
                }
            }
            // T-610 — stable L5 handle for the category → recipe journey.
            // Mirrors `dod.feed.card` / `dod.search.card`.
            .accessibilityIdentifier("dod.category.card")
            .task { await viewModel.loadMoreIfNeeded(currentItem: item) }
    }
}
