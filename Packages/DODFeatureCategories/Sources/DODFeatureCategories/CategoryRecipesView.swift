import DODDesignSystem
import DODDomain
import SwiftUI

public struct CategoryRecipesView: View {

    @State private var viewModel: CategoryRecipesViewModel
    public let onSelect: (RecipeListItem) -> Void

    public init(
        viewModel: CategoryRecipesViewModel,
        onSelect: @escaping (RecipeListItem) -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onSelect = onSelect
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
                LazyVStack(spacing: DODSpacing.md) {
                    ForEach(viewModel.items) { item in
                        recipeRow(item)
                    }
                    if viewModel.loadState == .loadingMore {
                        ProgressView()
                            .padding(.vertical, DODSpacing.lg)
                    }
                }
                .padding(DODSpacing.md)
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
        .onTapGesture { onSelect(item) }
        .task { await viewModel.loadMoreIfNeeded(currentItem: item) }
    }
}
