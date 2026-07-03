import DODDomain
import Foundation
import SwiftData
import Testing

@testable import DODPersistence

/// DUT-35 / DUT-6: the synced saved-recipe set. `toggleSaved` mirrors the local
/// pin into `SyncedSavedRecipe` (the ONLY CloudKit-mirrored model), the Saved
/// tab reads that synced set, and a one-time backfill seeds it from pre-V5
/// local saves. These run on the same two-configuration in-memory container the
/// app uses (both stores `.none` in tests).
@Suite("RecipeStore synced saved-set (DUT-35)")
struct SyncedSavedRecipeTests {

    private func url(_ string: String) -> URL {
        URL(string: string) ?? URL(filePath: "/dev/null")
    }

    private func sampleListItem(id: Int, title: String) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: title,
            excerpt: "Hearty and warming.",
            heroImage: url("https://dutchovendaddy.com/\(id).jpg"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: nil,
            canonicalURL: url("https://dutchovendaddy.com/\(id)")
        )
    }

    private func sampleRecipe(id: Int, title: String, isArticle: Bool = false) -> Recipe {
        Recipe(
            id: id,
            slug: "slug-\(id)",
            title: title,
            excerpt: "Excerpt",
            canonicalURL: url("https://dutchovendaddy.com/\(id)"),
            heroImage: url("https://dutchovendaddy.com/\(id).jpg"),
            heroImageLargeURL: nil,
            categoryIDs: [],
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            ingredients: [],
            instructions: [],
            prepTime: nil,
            cookTime: nil,
            totalTime: nil,
            servings: nil,
            nutrition: nil,
            video: nil,
            kind: isArticle ? .article : .recipe,
            articleBodyHTML: isArticle ? "<p>Body.</p>" : nil
        )
    }

    @Test("Saving writes the synced row; savedRecipes and isSaved read it")
    func saveWritesSyncedRow() async throws {
        let store = RecipeStore(modelContainer: try RecipeStore.inMemoryContainer())
        try await store.cache(listItem: sampleListItem(id: 1, title: "Dutch Oven Chili"))
        #expect(try await store.isSaved(id: 1) == false)

        let nowSaved = try await store.toggleSaved(id: 1)
        #expect(nowSaved)
        #expect(try await store.isSaved(id: 1))

        let saved = try await store.savedRecipes()
        #expect(saved.map(\.id) == [1])
        #expect(saved.first?.title == "Dutch Oven Chili")
    }

    @Test("Unsaving removes the synced row")
    func unsaveRemovesSyncedRow() async throws {
        let store = RecipeStore(modelContainer: try RecipeStore.inMemoryContainer())
        try await store.cache(listItem: sampleListItem(id: 2, title: "Cornbread"))
        _ = try await store.toggleSaved(id: 2)
        _ = try await store.toggleSaved(id: 2)
        #expect(try await store.isSaved(id: 2) == false)
        #expect(try await store.savedRecipes().isEmpty)
    }

    @Test("savedRecipeIDs returns the saved id set; unsaving removes from it")
    func savedRecipeIDsReflectsTheSavedSet() async throws {
        // T-765 / CL-162 (DUT-71) — the lightweight id projection the card
        // long-press menu reads to render the correct Save/Unsave label.
        let store = RecipeStore(modelContainer: try RecipeStore.inMemoryContainer())
        try await store.cache(listItem: sampleListItem(id: 10, title: "Chili"))
        try await store.cache(listItem: sampleListItem(id: 11, title: "Bread"))
        try await store.cache(listItem: sampleListItem(id: 12, title: "Stew"))
        #expect(try await store.savedRecipeIDs().isEmpty)

        _ = try await store.toggleSaved(id: 10)
        _ = try await store.toggleSaved(id: 12)
        #expect(try await store.savedRecipeIDs() == [10, 12])

        _ = try await store.toggleSaved(id: 10)
        #expect(try await store.savedRecipeIDs() == [12])
    }

    @Test("savedRecipes is ordered newest-saved first")
    func savedRecipesNewestFirst() async throws {
        let store = RecipeStore(modelContainer: try RecipeStore.inMemoryContainer())
        try await store.cache(listItem: sampleListItem(id: 10, title: "First"))
        try await store.cache(listItem: sampleListItem(id: 20, title: "Second"))
        _ = try await store.toggleSaved(id: 10)
        _ = try await store.toggleSaved(id: 20)
        #expect(try await store.savedRecipes().map(\.id) == [20, 10])
    }

    @Test("Backfill seeds the synced set from pre-V5 local pins, idempotently")
    func backfillSeedsFromLocalPins() async throws {
        let container = try RecipeStore.inMemoryContainer()
        // Simulate a pre-V5 local save: a CachedRecipe pinned isSaved == true
        // with NO synced row (the state an upgrading user's store is in).
        let setup = ModelContext(container)
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
        // The SYNCED store is empty pre-backfill (DUT-470: `savedRecipes()` now
        // unions the local pin for display, so assert the synced set directly).
        #expect(try await store.hasAnySyncedSaved() == false)

        try await store.backfillSyncedSaved()
        #expect(try await store.savedRecipes().map(\.id) == [3])
        #expect(try await store.isSaved(id: 3))

        // Idempotent: a second pass does not duplicate.
        try await store.backfillSyncedSaved()
        #expect(try await store.savedRecipes().count == 1)
    }

    @Test("mergeDetail reconciles the local pin from the synced set")
    func mergeReconcilesLocalPin() async throws {
        let container = try RecipeStore.inMemoryContainer()
        // A recipe saved on another device: a synced row arrives, but there is
        // no local CachedRecipe yet.
        let setup = ModelContext(container)
        setup.insert(
            SyncedSavedRecipe(
                id: 4,
                title: "Cross-device Save",
                excerptText: "Excerpt",
                canonicalURLString: "https://dutchovendaddy.com/4"
            )
        )
        try setup.save()

        let store = RecipeStore(modelContainer: container)
        #expect(try await store.isSaved(id: 4))  // synced truth says saved

        // Opening it caches CachedRecipe via mergeDetail, which must set the
        // local pin so LRU/widget see it.
        try await store.mergeDetail(sampleRecipe(id: 4, title: "Cross-device Save"))

        let verify = ModelContext(container)
        let pinned = try verify.fetch(
            FetchDescriptor<CachedRecipe>(predicate: #Predicate { $0.id == 4 })
        ).first
        #expect(pinned?.isSaved == true, "mergeDetail must pin a synced-saved recipe")
    }

    /// DUT-413 — the cross-device reconcile in `mergeDetail` must PIN the hero
    /// image too, not just flip `isSaved`. A recipe saved on another device
    /// caches its hero unpinned via the feed/widget prefetch, then reconciles to
    /// saved on detail open — without pinning, `evictImagesIfNeeded()` /
    /// `clearImageCache()` reclaim the bytes and the saved recipe loses its
    /// offline hero (AC-5.2), the same gap `toggleSaved` closes via `pinHeroImage`.
    @Test("mergeDetail pins the hero of a synced-saved recipe (DUT-413)")
    func mergePinsSyncedSavedHero() async throws {
        let container = try RecipeStore.inMemoryContainer()
        // A recipe saved on another device: synced row present, no local pin.
        let setup = ModelContext(container)
        setup.insert(
            SyncedSavedRecipe(
                id: 8,
                title: "Cross-device Cobbler",
                excerptText: "Excerpt",
                canonicalURLString: "https://dutchovendaddy.com/8"
            )
        )
        try setup.save()

        let store = RecipeStore(modelContainer: container)
        // Hero cached UNPINNED (the prefetch path) at the URL sampleRecipe uses.
        let heroURL = url("https://dutchovendaddy.com/8.jpg")
        try await store.cacheImage(url: heroURL, bytes: Data(repeating: 0x08, count: 2048))

        // Detail open reconciles the pin from the synced set.
        try await store.mergeDetail(sampleRecipe(id: 8, title: "Cross-device Cobbler"))

        let freed = try await store.clearImageCache()
        #expect(freed == 0, "mergeDetail must pin the synced-saved hero so it isn't reclaimed")
        #expect(try await store.image(url: heroURL) != nil)  // survives for offline use
    }

    @Test("Article saves carry the article discriminator into the synced row")
    func articleSaveTracksKind() async throws {
        let store = RecipeStore(modelContainer: try RecipeStore.inMemoryContainer())
        try await store.mergeDetail(sampleRecipe(id: 5, title: "Roundup", isArticle: true))
        _ = try await store.toggleSaved(id: 5)
        let saved = try await store.savedRecipes()
        #expect(saved.first?.kind == .article)
    }

    /// DUT-240 — the app's post-import reconcile branches on whether ANY
    /// synced row exists (a non-empty imported set means another ≥V5 device
    /// already seeded it, so local-only pins are cross-device unsaves).
    @Test("hasAnySyncedSaved reflects the synced set")
    func hasAnySyncedSavedReflectsTheSet() async throws {
        let store = RecipeStore(modelContainer: try RecipeStore.inMemoryContainer())
        #expect(try await store.hasAnySyncedSaved() == false)
        try await store.cache(listItem: sampleListItem(id: 9, title: "Chili"))
        _ = try await store.toggleSaved(id: 9)
        #expect(try await store.hasAnySyncedSaved())
        _ = try await store.toggleSaved(id: 9)  // unsave empties the set
        #expect(try await store.hasAnySyncedSaved() == false)
    }

    /// DUT-468 — a local save writes BOTH the synced row and the `isSaved` pin,
    /// so it appears in both id sets. An import-delivered row (a raw
    /// `SyncedSavedRecipe` insert with no `CachedRecipe`) appears only in the
    /// synced set — the discriminator the launch backfill relies on to tell a
    /// save made during the import wait from a genuinely remote save.
    @Test("syncedSavedIDSet / locallyPinnedSavedIDSet distinguish local saves from imports")
    func idSetsDistinguishLocalSaveFromImport() async throws {
        let container = try RecipeStore.inMemoryContainer()
        let store = RecipeStore(modelContainer: container)
        #expect(try await store.syncedSavedIDSet().isEmpty)
        #expect(try await store.locallyPinnedSavedIDSet().isEmpty)

        // A local save: both sets carry the id.
        try await store.cache(listItem: sampleListItem(id: 30, title: "Local Save"))
        _ = try await store.toggleSaved(id: 30)
        #expect(try await store.syncedSavedIDSet() == [30])
        #expect(try await store.locallyPinnedSavedIDSet() == [30])

        // An import-delivered row: a synced row with no local pin.
        let setup = ModelContext(container)
        setup.insert(
            SyncedSavedRecipe(
                id: 31,
                title: "Imported From Another Device",
                excerptText: "Excerpt",
                canonicalURLString: "https://dutchovendaddy.com/31"
            )
        )
        try setup.save()
        #expect(try await store.syncedSavedIDSet() == [30, 31])
        #expect(try await store.locallyPinnedSavedIDSet() == [30])  // 31 has no pin
    }

    /// DUT-470 — sync ON but the CloudKit mirror never lands an import (signed
    /// out of iCloud): the synced set is empty, but the upgrader's legacy local
    /// pins are real saves and must surface for DISPLAY so the Saved tab isn't
    /// blank every launch. Backfill-not-complete is the gate.
    @Test("Pre-backfill, a legacy local pin surfaces in the saved set (provisional display)")
    func provisionalPinsDisplayBeforeBackfill() async throws {
        let container = try RecipeStore.inMemoryContainer()
        let setup = ModelContext(container)
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
        // Backfill not complete (didBackfillSyncedSaved == false) → the legacy
        // pin surfaces even though the synced set is empty.
        #expect(try await store.savedRecipes().map(\.id) == [3])
        #expect(try await store.isSaved(id: 3))
        #expect(try await store.savedRecipeIDs() == [3])
    }

    /// DUT-470 — once the first real import reconciles and the backfill flag
    /// flips (here the skip branch: remote authoritative, pins NOT seeded), the
    /// synced set is the source of truth. A local-only pin is then a cross-device
    /// unsave and must NOT show — the provisional union stops. (No mirror write
    /// happened, so nothing resurrected.)
    @Test("After backfill completes, a local-only pin no longer shows (synced authoritative)")
    func provisionalPinsHiddenAfterBackfill() async throws {
        let container = try RecipeStore.inMemoryContainer()
        let setup = ModelContext(container)
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
        await store.markSyncedSavedBackfillComplete()  // first import reconciled
        #expect(try await store.savedRecipes().isEmpty)
        #expect(try await store.isSaved(id: 3) == false)
        #expect(try await store.savedRecipeIDs().isEmpty)
    }
}
