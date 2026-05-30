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
        // US-34 / AC-34.6 / CL-103 (T-634, 2026-05-29) — TODO: thread
        // per-card `isSaved` state once a Categories viewmodel-owned
        // `Set<Int>` of saved IDs (CL-60 path-(c)) is wired. Until then
        // `false` keeps the pre-T-634 "Save" + `bookmark.fill` copy at
        // this surface; the high-value Saved-tab fix is the priority for
        // T-634. RecipeListItem has no `isSaved` field, so the cheapest
        // follow-up is the viewmodel-owned set hydrated on appear.
        .recipeCardContextMenu(isSaved: false) { onSave?(item) }
        .task { await viewModel.loadMoreIfNeeded(currentItem: item) }
    }
}
