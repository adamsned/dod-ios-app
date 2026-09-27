import DODDomain
import SwiftUI

/// DUT-105 — the Saved tab's three collection sheets (create, rename, and
/// add-to-collection), bundled into one `ViewModifier` so `SavedView.body`
/// stays small and under the SwiftLint length caps. Each is driven by a binding
/// `SavedView` owns; all edits route to the shared ``SavedViewModel``.
struct CollectionSheets: ViewModifier {

    let viewModel: SavedViewModel
    @Binding var recipeForCollection: Recipe?
    @Binding var showingNewCollection: Bool
    @Binding var renamingCollection: RecipeCollection?

    func body(content: Content) -> some View {
        content
            .sheet(item: $recipeForCollection) { recipe in
                AddToCollectionSheet(
                    recipeTitle: recipe.title,
                    collections: viewModel.collections,
                    initialSelection: viewModel.membership(forRecipe: recipe.id),
                    onCreate: { name in await viewModel.addCollection(name: name) },
                    onCommit: { ids in
                        Task { await viewModel.setCollections(forRecipe: recipe.id, to: ids) }
                    }
                )
            }
            .sheet(isPresented: $showingNewCollection) {
                CollectionNameSheet(
                    title: "New Collection",
                    saveButtonTitle: "Create",
                    onSave: { name in
                        Task { await viewModel.createCollection(name: name) }
                    }
                )
            }
            .sheet(item: $renamingCollection) { collection in
                CollectionNameSheet(
                    title: "Rename Collection",
                    saveButtonTitle: "Save",
                    initialName: collection.name,
                    onSave: { name in
                        Task { await viewModel.renameCollection(id: collection.id, name: name) }
                    }
                )
            }
    }
}
