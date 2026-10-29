import DODDesignSystem
import DODDomain
import SwiftUI

/// DUT-105 — the "Add to Collection" sheet reached from a saved recipe card's
/// context menu. Shows every collection with a checkmark for the ones the recipe
/// is in, lets the user toggle membership across one or more, and offers an
/// inline "create a new collection" field. Done commits the whole selection at
/// once (``onCommit``); membership edits don't persist until then, but an
/// inline-created collection is created immediately (``onCreate``).
struct AddToCollectionSheet: View {

    let recipeTitle: String
    let onCreate: (String) async -> RecipeCollection?
    let onCommit: (Set<UUID>) -> Void

    @State private var collections: [RecipeCollection]
    @State private var selection: Set<UUID>
    @State private var newName = ""
    @Environment(\.dismiss) private var dismiss

    init(
        recipeTitle: String,
        collections: [RecipeCollection],
        initialSelection: Set<UUID>,
        onCreate: @escaping (String) async -> RecipeCollection?,
        onCommit: @escaping (Set<UUID>) -> Void
    ) {
        self.recipeTitle = recipeTitle
        self.onCreate = onCreate
        self.onCommit = onCommit
        _collections = State(initialValue: collections)
        _selection = State(initialValue: initialSelection)
    }

    var body: some View {
        NavigationStack {
            List {
                if !collections.isEmpty {
                    Section("Your Collections") {
                        ForEach(collections) { collection in
                            membershipRow(collection)
                        }
                    }
                }
                Section("New Collection") {
                    createRow
                }
            }
            .navigationTitle("Add to Collection")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onCommit(selection)
                        dismiss()
                    }
                    .accessibilityIdentifier("dod.saved.addToCollection.done")
                }
            }
        }
    }

    private func membershipRow(_ collection: RecipeCollection) -> some View {
        Button {
            toggle(collection.id)
        } label: {
            HStack {
                Text(collection.name)
                    .font(DODType.body)
                    .foregroundStyle(DODColor.label)
                Spacer()
                if selection.contains(collection.id) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(DODColor.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dod.saved.collectionMembershipRow")
    }

    private var createRow: some View {
        HStack(spacing: DODSpacing.xs) {
            TextField("Collection name", text: $newName)
                .font(DODType.body)
            Button("Create") {
                let name = newName
                newName = ""
                Task {
                    if let created = await onCreate(name) {
                        collections.append(created)
                        selection.insert(created.id)
                    }
                }
            }
            .font(DODType.caption)
            .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func toggle(_ id: UUID) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }
}
