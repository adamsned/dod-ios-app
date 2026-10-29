import DODDesignSystem
import SwiftUI

/// DUT-105 — the small name-entry sheet shared by "New Collection" (create) and
/// a chip's "Rename". A single text field plus Cancel / Save; Save is disabled
/// until the trimmed name is non-empty. Presentation only: it reports the
/// entered name through ``onSave`` and dismisses itself.
struct CollectionNameSheet: View {

    let title: String
    let saveButtonTitle: String
    let onSave: (String) -> Void

    @State private var name: String
    @Environment(\.dismiss) private var dismiss

    init(
        title: String,
        saveButtonTitle: String,
        initialName: String = "",
        onSave: @escaping (String) -> Void
    ) {
        self.title = title
        self.saveButtonTitle = saveButtonTitle
        self.onSave = onSave
        _name = State(initialValue: initialName)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Placeholder is sentence case per the copy rule.
                TextField("Collection name", text: $name)
                    .font(DODType.body)
                    .accessibilityIdentifier("dod.saved.collectionNameField")
            }
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saveButtonTitle) {
                        onSave(trimmedName)
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }
}
