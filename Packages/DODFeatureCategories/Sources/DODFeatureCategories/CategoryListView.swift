import DODDesignSystem
import DODDomain
import SwiftUI

/// All-categories list. Tapping a row notifies the host via `onSelect`.
public struct CategoryListView: View {

    @State private var viewModel: CategoryListViewModel
    public let onSelect: (DODDomain.Category) -> Void

    public init(
        viewModel: CategoryListViewModel,
        onSelect: @escaping (DODDomain.Category) -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onSelect = onSelect
    }

    public var body: some View {
        content
            .background(DODColor.surface)
            .navigationTitle("Categories")
            .task { await viewModel.onAppear() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DODColor.surface)
        case .error:
            EmptyState(
                systemImage: "exclamationmark.triangle",
                title: "Couldn't load categories",
                message: "Tap retry to try again.",
                action: .init(title: "Retry") {
                    Task { await viewModel.retry() }
                }
            )
        case .loaded:
            List(viewModel.categories) { category in
                Button {
                    onSelect(category)
                } label: {
                    HStack {
                        Text(category.name)
                            .dodFont(DODType.body)
                            .foregroundStyle(DODColor.label)
                        Spacer()
                        Text("\(category.count)")
                            .dodFont(DODType.caption)
                            .foregroundStyle(DODColor.labelSecondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(DODColor.labelSecondary)
                    }
                }
                .accessibilityLabel("\(category.name), \(category.count) recipes")
            }
            .listStyle(.plain)
        }
    }
}
