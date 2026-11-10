import DODDesignSystem
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
        Group {
            if !viewModel.axes.isEmpty {
                VStack(alignment: .leading, spacing: DODSpacing.md) {
                    ForEach(viewModel.axes) { axis in
                        section(axis)
                    }
                }
                .accessibilityIdentifier("browse.hub")
            }
        }
        .task { await viewModel.onAppear() }
    }
}

extension BrowseByView {
    func chip(axis: BrowseAxis, value: BrowseAxisValue) -> some View {
        Button(value.title) { onSelect(axis, value) }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("browse.\(axis.slug).\(value.slug)")
    }

    func section(_ axis: BrowseAxis) -> some View {
        VStack(alignment: .leading, spacing: DODSpacing.sm) {
            Text(axis.title).font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(axis.values) { value in
                        chip(axis: axis, value: value)
                    }
                }
            }
        }
    }
}
