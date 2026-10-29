import DODDomain
import DODSupport
import Foundation

// MARK: - Add to Collection picker (DUT-1340)
//
// The long-press bookmark presents `RecipeCollectionPickerSheet`, which reads
// its collections + seed selection from the two published properties on the
// view model (loaded here) and reports back through these action methods. All
// collection I/O routes through the `RecipeDetailDependencies` data seam so
// recipe detail never depends on `DODFeatureSaved`.
extension RecipeDetailViewModel {

    /// Fetch every collection + the recipe's current membership, storing them on
    /// the view model so the picker sheet can present pre-populated. Called by
    /// the menu action just before the sheet is shown. No-ops (leaves empty
    /// state) when the recipe hasn't loaded or a read fails — the picker then
    /// just offers the "create a new collection" row.
    public func loadCollectionsForPicker() async {
        guard let recipe else { return }
        pickerCollections = (try? await dependencies.collections()) ?? []
        pickerInitialSelection = (try? await dependencies.collectionIDs(forRecipe: recipe.id)) ?? []
    }

    /// Create a collection inline from the picker's "create" field, routing to
    /// the dependency seam. Returns the created value (so the sheet can append +
    /// auto-select it), or `nil` on failure.
    public func createCollectionFromPicker(name: String) async -> RecipeCollection? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return try? await dependencies.createCollection(name: trimmed)
    }

    /// Commit the picker's collection selection for the current recipe.
    ///
    /// Save-first semantics (DUT-1340): membership is a subset of the saved set,
    /// so a recipe added to a collection while unsaved would be pruned on the
    /// unsave path and filtered out of `recipes(inCollection:)`. Therefore a
    /// non-empty selection on a not-yet-saved recipe SAVES it first, driving the
    /// same ``toggleSaved()`` path (telemetry + widget snapshot republish) the
    /// bookmark tap uses. An empty selection never force-saves.
    public func commitCollections(_ ids: Set<UUID>) async {
        guard let recipe else { return }
        if !ids.isEmpty, !isSaved {
            await toggleSaved()
        }
        do {
            try await dependencies.setCollections(forRecipe: recipe.id, to: ids)
            if !ids.isEmpty {
                snackbarMessage = "Added to your collections."
            }
        } catch {
            DODLog.persistence.error(
                "commit collections failed: \(String(describing: error))"
            )
        }
    }
}
