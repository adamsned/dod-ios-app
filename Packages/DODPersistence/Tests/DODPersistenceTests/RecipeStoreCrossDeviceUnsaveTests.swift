import DODDomain
import Foundation
import SwiftData
import Testing

@testable import DODPersistence

/// DUT-732 — a recipe saved on ANOTHER device and imported via CloudKit surfaces
/// in the Saved tab through `SyncedSavedRecipe`, but its local `CachedRecipe`
/// `isSaved` pin is never reconciled unless its detail is opened on this device.
/// `toggleSaved` used to decide save-vs-unsave from that stale local pin, so
/// tapping Unsave on such a card RE-SAVED it (pin `false` → toggle → `true`)
/// instead of removing it. The decision must come from the synced source of
/// truth (`isSaved(id:)`), so the first tap genuinely removes it.
@Suite("Cross-device unsave uses the synced source of truth (DUT-732)")
struct RecipeStoreCrossDeviceUnsaveTests {

    @Test("Unsaving a cross-device-saved recipe (no local pin) removes it")
    func unsaveCrossDeviceSavedRecipeRemovesIt() async throws {
        let container = try RecipeStore.inMemoryContainer()
        let setup = ModelContext(container)
        // Cross-device state: a synced row exists (a CloudKit import) while the
        // local CachedRecipe pin stays `false` — never reconciled because the
        // recipe's detail was not opened on this device.
        setup.insert(
            SyncedSavedRecipe(
                id: 42,
                savedAt: Date(timeIntervalSince1970: 1_700_000_000),
                title: "Cross-Device Lasagna",
                excerptText: "Excerpt",
                canonicalURLString: "https://dutchovendaddy.com/42"
            )
        )
        setup.insert(
            CachedRecipe(
                id: 42,
                slug: "lasagna",
                title: "Cross-Device Lasagna",
                excerptText: "Excerpt",
                canonicalURLString: "https://dutchovendaddy.com/42",
                publishedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        )
        try setup.save()

        let store = RecipeStore(modelContainer: container)
        // Precondition: it reads as saved (from the synced set) despite the
        // `false` local pin — this is exactly the Saved-tab card the user taps.
        #expect(try await store.savedRecipeIDs().contains(42))

        // Tap Unsave.
        let nowSaved = try await store.toggleSaved(id: 42)

        // DUT-732: the first tap REMOVES it (returns unsaved + drops the synced
        // row). Before the fix it re-saved (returned `true`, row survived).
        #expect(nowSaved == false)
        #expect(try await store.savedRecipeIDs().isEmpty)
    }
}
