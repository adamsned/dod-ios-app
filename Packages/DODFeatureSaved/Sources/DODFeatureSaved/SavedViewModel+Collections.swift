import DODDomain
import DODSupport
import Foundation

// DUT-105 — the collections / cookbooks half of the Saved-tab view model: the
// shelf filter, the CRUD the manage + create sheets call, and the membership
// the "Add to Collection" sheet reads and writes. Kept in an extension so the
// core `SavedViewModel` stays under the SwiftLint `file_length` cap. (Stored
// state — `collections`, `selectedCollectionID` — lives on the class itself,
// since `@Observable` can only track stored properties declared there.)
extension SavedViewModel {

    /// The recipes to show in the grid/list: the whole saved set for "All Saved"
    /// (`selectedCollectionID == nil`), or just a collection's members when one
    /// is selected, preserving the saved-set (newest-first) order.
    public var displayedRecipes: [Recipe] {
        guard
            let selectedCollectionID,
            let collection = collections.first(where: { $0.id == selectedCollectionID })
        else {
            return recipes
        }
        let members = Set(collection.recipeIDs)
        return recipes.filter { members.contains($0.id) }
    }

    /// The currently-selected collection, if any (nil for "All Saved").
    public var selectedCollection: RecipeCollection? {
        guard let selectedCollectionID else { return nil }
        return collections.first { $0.id == selectedCollectionID }
    }

    /// Commit a freshly-loaded collections list, clearing a stale selection that
    /// points at a collection that no longer exists (e.g. deleted on another
    /// device). Called from ``refresh()`` and the CRUD helpers below.
    func applyCollections(_ loaded: [RecipeCollection]) {
        collections = loaded
        if let selectedCollectionID, !loaded.contains(where: { $0.id == selectedCollectionID }) {
            self.selectedCollectionID = nil
        }
    }

    /// Switch the shelf filter. `nil` shows the flat "All Saved" list.
    public func selectCollection(_ id: UUID?) {
        selectedCollectionID = id
    }

    /// Reload just the collections list (the view's `.task` calls this alongside
    /// ``refresh()``; CRUD helpers call it to reflect their edit).
    public func loadCollections() async {
        do {
            applyCollections(try await dependencies.collections())
        } catch {
            DODLog.persistence.error("collections load failed: \(String(describing: error))")
        }
    }

    /// Create a collection, reload the shelf, and return the created value.
    /// Does NOT change the shelf filter — the "Add to Collection" sheet's inline
    /// create uses this so making a new cookbook mid-sheet doesn't yank the shelf
    /// behind it. Returns `nil` on an empty name or a store failure.
    @discardableResult
    public func addCollection(name: String) async -> RecipeCollection? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        do {
            let created = try await dependencies.createCollection(name: trimmed)
            await loadCollections()
            return created
        } catch {
            DODLog.persistence.error("create collection failed: \(String(describing: error))")
            return nil
        }
    }

    /// Create a collection and select it so the shelf jumps to the new cookbook
    /// (the "New Collection" chip's create flow).
    public func createCollection(name: String) async {
        if let created = await addCollection(name: name) {
            selectedCollectionID = created.id
        }
    }

    /// Rename a collection.
    public func renameCollection(id: UUID, name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try await dependencies.renameCollection(id: id, name: trimmed)
            await loadCollections()
        } catch {
            DODLog.persistence.error("rename collection failed: \(String(describing: error))")
        }
    }

    /// Delete a collection, clearing the shelf filter if it was selected.
    public func deleteCollection(id: UUID) async {
        if selectedCollectionID == id { selectedCollectionID = nil }
        do {
            try await dependencies.deleteCollection(id: id)
            await loadCollections()
        } catch {
            DODLog.persistence.error("delete collection failed: \(String(describing: error))")
        }
    }

    /// The collection ids a recipe belongs to — the seed for the "Add to
    /// Collection" sheet's checkmarks. Best-effort: an empty set on failure.
    public func collectionMembership(forRecipe recipeID: Int) async -> Set<UUID> {
        (try? await dependencies.collectionIDs(forRecipe: recipeID)) ?? []
    }

    /// The recipe's membership computed synchronously from the already-loaded
    /// ``collections`` (each carries its `recipeIDs`), so the "Add to Collection"
    /// sheet can seed its checkmarks at present-time without an `await`.
    public func membership(forRecipe recipeID: Int) -> Set<UUID> {
        Set(collections.filter { $0.recipeIDs.contains(recipeID) }.map(\.id))
    }

    /// Set exactly which collections a recipe belongs to, then reload so the
    /// shelf counts and any active filter reflect the change.
    public func setCollections(forRecipe recipeID: Int, to ids: Set<UUID>) async {
        do {
            try await dependencies.setCollections(forRecipe: recipeID, to: ids)
            await loadCollections()
        } catch {
            DODLog.persistence.error("set collections failed: \(String(describing: error))")
        }
    }
}
