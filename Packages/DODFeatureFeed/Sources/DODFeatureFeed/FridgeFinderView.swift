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

    private func submitNewItem() {
        let name = newItem.trimmingCharacters(in: .whitespacesAndNewlines)
        newItem = ""
        guard !name.isEmpty else { return }
        Task { await viewModel.addIngredient(name) }
    }

    private var photoSection: some View {
        Section {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Photograph your fridge", systemImage: "camera")
            }
            .accessibilityIdentifier("fridgeFinder.photoPicker")
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        switch viewModel.phase {
        case .identifying:
            Section { ProgressView("Looking at your ingredients") }
        case .noIngredients:
            Section { Text("No ingredients spotted. Try a clearer photo.") }
        case .results, .idle:
            EmptyView()
        }
    }

    private var ingredientsSection: some View {
        Section("Ingredients") {
            ForEach(viewModel.ingredients, id: \.self) { name in
                HStack {
                    Text(name)
                        .dodFont(DODType.body)
                    Spacer()
                    Button {
                        Task { await viewModel.removeIngredient(name) }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(name)")
                    .accessibilityIdentifier("fridgeFinder.remove.\(name)")
                }
            }
            TextField("Add item", text: $newItem)
                .onSubmit { submitNewItem() }
                .accessibilityIdentifier("fridgeFinder.addItem")
        }
    }

    private var resultsSection: some View {
        Section("Recipes you can make") {
            ForEach(viewModel.matches) { match in
                Button {
                    onSelect(match.recipeID)
                } label: {
                    VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                        Text(match.title)
                            .dodFont(DODType.body)
                        Text(
                            "\(match.matchedLines.count) of "
                                + "\(match.matchedLines.count + match.missingLines.count) ingredients on hand"
                        )
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.labelSecondary)
                    }
                }
                .accessibilityIdentifier("fridgeFinder.match.\(match.recipeID)")
            }
        }
    }

    public var body: some View {
        List {
            photoSection
            statusSection
            if !viewModel.ingredients.isEmpty { ingredientsSection }
            if !viewModel.matches.isEmpty { resultsSection }
        }
        .navigationTitle("What Can I Cook Tonight?")
        .onChange(of: pickerItem) { _, item in
            Task { await loadPickedImage(item) }
        }
    }
}

#Preview {
    NavigationStack {
        FridgeFinderView(
            viewModel: FridgeFinderViewModel(
                intelligence: FakeIntelligenceService(),
                loadRecipes: { [] }
            ),
            onSelect: { _ in }
        )
    }
}
