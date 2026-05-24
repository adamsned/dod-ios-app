import DODDesignSystem
import DODDomain
import SwiftUI

public struct SearchView: View {

    @State private var viewModel: SearchViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    public let onSelect: (RecipeListItem) -> Void

    public init(viewModel: SearchViewModel, onSelect: @escaping (RecipeListItem) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: 0) {
            searchField
            content
        }
        .background(DODColor.surface)
        .navigationTitle("Search")
    }

    private var searchField: some View {
        HStack(spacing: DODSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DODColor.labelSecondary)
            TextField("Search recipes", text: $viewModel.query)
                .autocorrectionDisabled()
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
            if !viewModel.query.isEmpty {
                Button {
                    viewModel.clear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DODColor.labelSecondary)
                }
                .accessibilityLabel("Clear")
            }
        }
        .padding(DODSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DODSpacing.sm, style: .continuous)
                .fill(DODColor.surfaceElevated)
        )
        .padding(DODSpacing.md)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            EmptyState(
                systemImage: "magnifyingglass",
                title: "Find a recipe",
                message: "Type at least 2 characters to search."
            )
        case .searching:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .noResults:
            EmptyState(
                systemImage: "questionmark.folder",
                title: "No recipes match '\(viewModel.query)'",
                message: "Try a different word."
            )
        case .offline:
            EmptyState(
                systemImage: "wifi.slash",
                title: "Search needs internet",
                message: "Reconnect to search dutchovendaddy.com."
            )
        case .results:
            ScrollView {
                LazyVGrid(
                    columns: recipeGridColumns(horizontalSizeClass: horizontalSizeClass),
                    spacing: DODSpacing.md
                ) {
                    ForEach(viewModel.items) { item in
                        RecipeCard(
                            title: item.title,
                            excerpt: item.excerpt,
                            heroImageURL: item.heroImage,
                            totalTimeDisplay: item.totalTimeDisplay
                        )
                        .recipeCardTap { onSelect(item) }
                    }
                }
                .padding(.horizontal, DODSpacing.md)
                .padding(.bottom, DODSpacing.lg)
            }
        }
    }
}
