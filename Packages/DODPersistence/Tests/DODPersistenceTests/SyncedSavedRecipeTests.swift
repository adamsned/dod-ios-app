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
        #expect(try await store.savedRecipes().isEmpty)  // synced store empty pre-backfill

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

    @Test("Article saves carry the article discriminator into the synced row")
    func articleSaveTracksKind() async throws {
        let store = RecipeStore(modelContainer: try RecipeStore.inMemoryContainer())
        try await store.mergeDetail(sampleRecipe(id: 5, title: "Roundup", isArticle: true))
        _ = try await store.toggleSaved(id: 5)
        let saved = try await store.savedRecipes()
        #expect(saved.first?.kind == .article)
    }
}
