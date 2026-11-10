import DODDesignSystem
import DODDomain
import DODIntelligence
import PhotosUI
import SwiftUI

/// DUT-1979 (DUT-1009 part 6) — fridge photo -> ingredient chips -> ranked recipes.
public struct FridgeFinderView: View {
    @State private var viewModel: FridgeFinderViewModel
    @State private var pickerItem: PhotosPickerItem?
    @State private var newItem = ""
    private let onSelect: (Int) -> Void

    public init(viewModel: FridgeFinderViewModel, onSelect: @escaping (Int) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSelect = onSelect
    }

    public var body: some View {
        List {}
            .navigationTitle("What Can I Cook Tonight?")
    }
}
