import Foundation

// DUT-162 — the SwiftData half of "Export My Data": read the two locally-stored
// user models this store owns (the synced saved set + the local cook journal)
// and project them into the portable export shapes. The shopping list + profile
// live in other stores and are gathered by the composition root, which composes
// the full `DataExportDocument`.
//
// Extracted from `RecipeStore.swift` so that file stays under the SwiftLint
// `file_length` cap, matching the existing `RecipeStore+*` split pattern.
extension RecipeStore {

    /// Every saved recipe (or saved article), newest-save-first, projected into
    /// the export shape. Reuses ``savedRecipesWithSavedAt()`` so the export sees
    /// the exact same deduped saved set the Saved tab renders (including the
    /// pre-backfill provisional legacy pins, which surface with a
    /// `.distantPast` save time). Returns an empty array when nothing is saved.
    public func exportedSavedRecipes() throws -> [DataExportSavedRecipe] {
        try savedRecipesWithSavedAt().map { DataExportSavedRecipe(recipe: $0.recipe, savedAt: $0.savedAt) }
    }

    /// Every cooking-journal entry, newest-first, projected into the export
    /// shape. Reuses ``allCookLogs()``. Returns an empty array when the journal
    /// is empty.
    public func exportedJournalEntries() throws -> [DataExportJournalEntry] {
        try allCookLogs().map(DataExportJournalEntry.init(entry:))
    }
}
