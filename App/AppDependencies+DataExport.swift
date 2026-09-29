import DODDomain
import DODFeatureProfile
import DODFeatureSaved
import DODPersistence
import Foundation

// DUT-162 — the composition-root half of "Export My Data". This is the only
// layer that can see all four on-device stores at once (the SwiftData
// `RecipeStore`, the App-Group shopping list, the Keychain profile), so it
// gathers each section, composes the portable `DataExportDocument`, and writes
// it to a temp file for the system share sheet.
//
// Pure read-and-serialize: no network, and it succeeds for a guest user with no
// account and no saved data (every section degrades to empty / nil). Split out
// of `AppDependencies.swift` to keep that file under the SwiftLint 400-line cap.
extension AppDependencies {

    /// Gather every on-device user record into one JSON file and return its URL.
    /// `static` + explicit `store` / `profileStore` params (rather than an
    /// instance method) so the `settingsDependencies()` seam can capture just
    /// the two `Sendable` actors in its `@Sendable` closure, not all of `self`.
    static func makeDataExportFile(
        store: RecipeStore,
        profileStore: KeychainProfileStore
    ) async throws -> URL {
        let service = DataExportService()
        let saved = try await store.exportedSavedRecipes()
        let journal = try await store.exportedJournalEntries()
        let shopping = exportedShoppingList()
        let profile = await exportedProfile(from: profileStore)
        let document = service.makeDocument(
            savedRecipes: saved,
            journalEntries: journal,
            shoppingList: shopping,
            profile: profile
        )
        return try service.write(document)
    }

    /// Map the Keychain profile into the export shape, or `nil` for a guest.
    private static func exportedProfile(
        from profileStore: KeychainProfileStore
    ) async -> DataExportProfile? {
        guard let profile = await profileStore.load() else { return nil }
        return DataExportProfile(
            id: profile.id,
            displayName: profile.displayName,
            email: profile.email,
            photoFilename: profile.photoFilename
        )
    }

    /// Read the persisted App-Group shopping list and flatten each row plus its
    /// ephemeral check / already-have state into the export shape. Empty when
    /// nothing is persisted or the App-Group suite can't be opened.
    private static func exportedShoppingList() -> [DataExportShoppingListItem] {
        guard let snapshot = ShoppingListStore()?.load() else { return [] }
        let checked = Set(snapshot.checkedIDs)
        let alreadyHave = Set(snapshot.alreadyHaveIDs)
        return snapshot.items.map { item in
            DataExportShoppingListItem(
                id: item.id,
                ingredientText: item.ingredientText,
                recipeTitle: item.recipeTitle,
                aisle: item.aisle.rawValue,
                isChecked: checked.contains(item.id),
                alreadyHave: alreadyHave.contains(item.id)
            )
        }
    }
}
