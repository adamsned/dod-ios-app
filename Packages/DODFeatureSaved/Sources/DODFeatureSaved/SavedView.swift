import DODDesignSystem
import DODDomain
import SwiftUI

public struct SavedView: View {

    @State private var viewModel: SavedViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    public let onSelect: (Recipe) -> Void

    public init(viewModel: SavedViewModel, onSelect: @escaping (Recipe) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSelect = onSelect
    }

    public var body: some View {
        content
            .background(DODColor.surface)
            .navigationTitle("Saved")
            .task { await viewModel.refresh() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            EmptyState(
                systemImage: "heart",
                title: "No saved recipes yet",
                message: "Tap the heart on any recipe to save it for offline."
            )
        case .error:
            EmptyState(
                systemImage: "exclamationmark.triangle",
                title: "Couldn't load saved recipes",
                message: "Try again in a moment.",
                action: .init(title: "Retry") {
                    Task { await viewModel.refresh() }
                }
            )
        case .loaded:
            ScrollView {
                LazyVGrid(
                    columns: recipeGridColumns(horizontalSizeClass: horizontalSizeClass),
                    spacing: DODSpacing.md
                ) {
                    ForEach(viewModel.recipes) { recipe in
                        Button {
                            onSelect(recipe)
                        } label: {
                            RecipeCard(
                                title: recipe.title,
                                excerpt: recipe.excerpt,
                                heroImageURL: recipe.heroImage,
                                totalTimeDisplay: totalTimeDisplay(recipe)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DODSpacing.md)
                .padding(.vertical, DODSpacing.md)
            }
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
