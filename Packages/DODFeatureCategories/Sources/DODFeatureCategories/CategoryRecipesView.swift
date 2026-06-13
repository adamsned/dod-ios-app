import DODDesignSystem
import DODDomain
import SwiftUI

public struct CategoryRecipesView: View {

    @State private var viewModel: CategoryRecipesViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    public let onSelect: (RecipeListItem) -> Void
    /// US-34 / AC-34.1 — long-press → "Save" context menu wiring. See
    /// `FeedView.onSave` for the contract; same shape applied to category
    /// recipe lists.
    public let onSave: ((RecipeListItem) -> Void)?

    public init(
        viewModel: CategoryRecipesViewModel,
        onSelect: @escaping (RecipeListItem) -> Void,
        onSave: ((RecipeListItem) -> Void)? = nil
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
        case .empty:
            EmptyState(
                systemImage: "tray",
                title: "No recipes here",
                message: "Try a different category."
            )
        case .loaded, .loadingMore:
            ScrollView {
                LazyVGrid(
                    columns: recipeGridColumns(horizontalSizeClass: horizontalSizeClass),
                    spacing: DODSpacing.md
                ) {
                    ForEach(viewModel.items) { item in
                        recipeRow(item)
                    }
                }
                .padding(DODSpacing.md)

                if viewModel.loadState == .loadingMore {
                    ProgressView()
                        .padding(.vertical, DODSpacing.lg)
                }
            }
        }
    }

    private func recipeRow(_ item: RecipeListItem) -> some View {
        RecipeCard(
            title: item.title,
            excerpt: item.excerpt,
            heroImageURL: item.heroImage,
            totalTimeDisplay: item.totalTimeDisplay
        )
        .recipeCardTap { onSelect(item) }
        // T-765 / CL-162 (DUT-71) — state-aware Save/Unsave from the
        // viewmodel-owned saved-id set; optimistic flip on toggle.
        .recipeCardContextMenu(isSaved: viewModel.savedRecipeIDs.contains(item.id)) {
            viewModel.applyOptimisticSaveToggle(id: item.id)
            onSave?(item)
        }
        .task { await viewModel.loadMoreIfNeeded(currentItem: item) }
    }
}
