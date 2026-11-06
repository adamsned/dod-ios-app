import DODDomain
import SwiftUI

public struct BrowseByView: View {
    @State private var viewModel: BrowseByViewModel
    private let onSelect: (BrowseAxis, BrowseAxisValue) -> Void

    public init(
        viewModel: BrowseByViewModel,
        onSelect: @escaping (BrowseAxis, BrowseAxisValue) -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onSelect = onSelect
    }

    public var body: some View {
        Group { EmptyView() }
            .task { await viewModel.onAppear() }
    }
}
