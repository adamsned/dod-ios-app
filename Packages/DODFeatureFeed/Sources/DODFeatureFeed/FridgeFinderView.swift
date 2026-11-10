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

    private func loadPickedImage(_ item: PhotosPickerItem?) async {
        guard let item,
            let data = try? await item.loadTransferable(type: Data.self)
        else { return }
        await viewModel.analyze(imageData: data)
    }

    private var photoSection: some View {
        Section {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Photograph your fridge", systemImage: "camera")
            }
            .accessibilityIdentifier("fridgeFinder.photoPicker")
        }
    }

    public var body: some View {
        List {
            photoSection
        }
        .navigationTitle("What Can I Cook Tonight?")
        .onChange(of: pickerItem) { _, item in
            Task { await loadPickedImage(item) }
        }
    }
}
