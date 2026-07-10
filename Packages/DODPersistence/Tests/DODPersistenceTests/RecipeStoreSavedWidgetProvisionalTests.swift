import DODDomain
import Foundation
import SwiftData
import Testing

@testable import DODPersistence

/// DUT-735 — the Saved widget projection + count must union the pre-backfill
/// provisional pins that the Saved tab / Settings stat / Spotlight already show.
/// Otherwise a pre-V5 upgrader (sync on, CloudKit mirror unavailable) sees a
/// populated Saved tab but an EMPTY home-screen widget and a 0 lock-screen
/// badge. Self-gates: once the first import reconciles (backfill complete), the
/// synced set is authoritative and the provisional union stops.
@Suite("RecipeStore saved widget provisional-pin union (DUT-735)")
struct RecipeStoreSavedWidgetProvisionalTests {

    @Test func widgetProjectionAndCountUnionProvisionalPinsUntilBackfill() async throws {
        let container = try RecipeStore.inMemoryContainer()
        let setup = ModelContext(container)
        // A pre-V5 legacy save: an `isSaved` CachedRecipe with NO synced row.
        setup.insert(
            CachedRecipe(
                id: 3,
                slug: "pre-v5",
                title: "Pre-V5 Save",
                excerptText: "Excerpt",
                canonicalURLString: "https://dutchovendaddy.com/3",
                publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
                isSaved: true
            )
        )
        try setup.save()

        let store = RecipeStore(modelContainer: container)
        // Pre-backfill (didBackfillSyncedSaved == false): the provisional pin
        // surfaces in BOTH widget surfaces, matching every other saved surface.
        #expect(try await store.savedRecipesForWidget(limit: 5).map(\.recipeID) == [3])
        #expect(try await store.savedRecipeCount() == 1)

        // Once the first import reconciles, the provisional union stops — both
        // the widget projection AND the badge count go empty.
        await store.markSyncedSavedBackfillComplete()
        #expect(try await store.savedRecipesForWidget(limit: 5).isEmpty)
        #expect(try await store.savedRecipeCount() == 0)
    }
}
