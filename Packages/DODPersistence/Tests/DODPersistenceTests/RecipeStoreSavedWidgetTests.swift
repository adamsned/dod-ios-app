import DODDomain
import Foundation
import Testing

@testable import DODPersistence

/// Spec trace: US-17 / AC-17.3 (host-side payload construction).
/// Pinned by T-322 (SavedStore observation + snapshot writer wiring).
@Suite("RecipeStore.savedRecipesForWidget (T-322)") struct RecipeStoreSavedWidgetTests {

    @Test func emptyWhenNoRecipesAreSaved() async throws {
        let store = try await makeStore()
        try await store.cache(listItem: Self.makeWidgetListItem(id: 1, title: "Unsaved"))
        let rows = try await store.savedRecipesForWidget(limit: 3)
        #expect(rows.isEmpty)
    }

    @Test func returnsOnlySavedRecipesSortedByLastViewedDesc() async throws {
        let store = try await makeStore()
        // Cache + save three rows whose `lastViewedAt` is set by
        // `cache(listItem:)` to .now at insert time. Sleep between inserts
        // so each `lastViewedAt` is observably distinct.
        try await store.cache(listItem: Self.makeWidgetListItem(id: 1, title: "First"))
        try await Task.sleep(nanoseconds: 1_000_000)
        try await store.cache(listItem: Self.makeWidgetListItem(id: 2, title: "Second"))
        try await Task.sleep(nanoseconds: 1_000_000)
        try await store.cache(listItem: Self.makeWidgetListItem(id: 3, title: "Third"))
        // Also cache an unsaved one to prove it's filtered out.
        try await store.cache(listItem: Self.makeWidgetListItem(id: 99, title: "Unsaved"))
        _ = try await store.toggleSaved(id: 1)
        _ = try await store.toggleSaved(id: 2)
        _ = try await store.toggleSaved(id: 3)
        let rows = try await store.savedRecipesForWidget(limit: 3)
        #expect(rows.map(\.recipeID) == [3, 2, 1], "Newest-saved-first ordering")
        #expect(rows.allSatisfy { $0.recipeID != 99 }, "Unsaved row must be excluded")
    }

    @Test func limitTrimsTheReturnedSet() async throws {
        let store = try await makeStore()
        for index in 1...5 {
            try await store.cache(listItem: Self.makeWidgetListItem(id: index, title: "R\(index)"))
            try await Task.sleep(nanoseconds: 1_000_000)
            _ = try await store.toggleSaved(id: index)
        }
        let rows = try await store.savedRecipesForWidget(limit: 3)
        #expect(rows.count == 3)
        // Most-recently-saved first.
        #expect(rows.map(\.recipeID) == [5, 4, 3])
    }

    @Test func limitZeroReturnsEmpty() async throws {
        let store = try await makeStore()
        try await store.cache(listItem: Self.makeWidgetListItem(id: 1, title: "A"))
        _ = try await store.toggleSaved(id: 1)
        let rows = try await store.savedRecipesForWidget(limit: 0)
        #expect(rows.isEmpty)
    }

    @Test func heroImageCachedFlagReflectsImageStore() async throws {
        let store = try await makeStore()
        let heroURL = URL(string: "https://example.com/1.jpg") ?? URL(filePath: "/")
        try await store.cache(listItem: Self.makeWidgetListItem(id: 1, title: "Cached"))
        try await store.cache(listItem: Self.makeWidgetListItem(id: 2, title: "Uncached"))
        _ = try await store.toggleSaved(id: 1)
        _ = try await store.toggleSaved(id: 2)
        // Only id 1's image is in the cache. `makeWidgetListItem` sets
        // `heroImage` to `https://example.com/<id>.jpg`, so the URL we
        // cache matches id 1's stored URL.
        try await store.cacheImage(url: heroURL, bytes: Data([0xFF]), pinnedToSavedRecipeID: 1)
        let rows = try await store.savedRecipesForWidget(limit: 5)
        let byID = Dictionary(uniqueKeysWithValues: rows.map { ($0.recipeID, $0) })
        let cachedRow = try #require(byID[1])
        let uncachedRow = try #require(byID[2])
        #expect(cachedRow.heroImageCached == true)
        #expect(uncachedRow.heroImageCached == false)
    }

    @Test func savedAtMatchesLastViewedAt() async throws {
        let store = try await makeStore()
        let before = Date()
        try await store.cache(listItem: Self.makeWidgetListItem(id: 1, title: "Stamped"))
        _ = try await store.toggleSaved(id: 1)
        let after = Date()
        let rows = try await store.savedRecipesForWidget(limit: 3)
        let stamp = try #require(rows.first?.savedAt)
        #expect(stamp >= before)
        #expect(stamp <= after)
    }

    @Test func skipsRowsWithEmptyCanonicalURL() async throws {
        // Insert via the model context directly so we can construct a row
        // with an empty canonicalURLString. `cache(listItem:)` writes empty
        // strings when the inbound `RecipeListItem.canonicalURL` is nil
        // (see RecipeStore.swift line 45). The widget tap-through needs a
        // usable URL (AC-17.4), so blank rows must be skipped.
        let store = try await makeStore()
        try await store.insertSavedRowWithBlankCanonical(id: 42, title: "Orphan")
        let rows = try await store.savedRecipesForWidget(limit: 3)
        #expect(rows.isEmpty, "Row with empty canonicalURL must be skipped")
    }

    /// T-774 / DUT-80 — the Saved tab's "Downloaded" badge reads this set
    /// (`downloadedRecipeIDs()`, defined alongside the widget projection in
    /// `RecipeStore+SavedWidget.swift`). Returns ids of rows with
    /// `downloadedAt != nil`; cached-but-never-downloaded rows are excluded.
    @Test func downloadedRecipeIDsReturnsOnlyDownloadedRows() async throws {
        let store = try await makeStore()
        for id in [101, 102, 103] {
            try await store.cache(listItem: makeListItem(id: id, title: "R\(id)"))
        }
        _ = try await store.markDownloaded(id: 101)
        _ = try await store.markDownloaded(id: 103)
        #expect(try await store.downloadedRecipeIDs() == [101, 103])
        // 102 was cached but never downloaded → excluded.
        #expect(try await store.downloadedRecipeIDs().contains(102) == false)
    }

    /// T-775 / DUT-81 — ``RecipeStore/removeDownload(id:)`` clears the download
    /// pin so a downloaded recipe reverts to saved-only, is an idempotent no-op
    /// on a not-downloaded row, and the recipe can be re-downloaded afterward.
    @Test func removeDownloadClearsThePinAndIsIdempotent() async throws {
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 201, title: "Pinned"))
        _ = try await store.markDownloaded(id: 201)
        #expect(try await store.isDownloaded(id: 201) == true)

        // Removal transitions (true) and clears the flag.
        #expect(try await store.removeDownload(id: 201) == true)
        #expect(try await store.isDownloaded(id: 201) == false)
        #expect(try await store.downloadedRecipeIDs().contains(201) == false)

        // Idempotent: a second removal on a not-downloaded row is a no-op.
        #expect(try await store.removeDownload(id: 201) == false)

        // The recipe can be re-downloaded after removal (full toggle cycle).
        #expect(try await store.markDownloaded(id: 201) == true)
        #expect(try await store.isDownloaded(id: 201) == true)
    }

    // MARK: - Helpers

    /// Local helper that mirrors `makeListItem(id:title:)` but populates
    /// `canonicalURL` — `RecipeStore.savedRecipesForWidget` skips rows
    /// without one (AC-17.4 needs a tap target), so every fixture row here
    /// has to carry a URL.
    static func makeWidgetListItem(id: Int, title: String) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: title,
            excerpt: "An excerpt.",
            heroImage: URL(string: "https://example.com/\(id).jpg"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000 + TimeInterval(id)),
            totalTimeDisplay: nil,
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/\(id)/")
        )
    }
}

extension RecipeStore {

    /// Test-only seam: insert a saved CachedRecipe with an empty
    /// canonicalURLString to exercise the skip-on-blank-URL branch in
    /// `savedRecipesForWidget(limit:)`. Production never writes empty URLs.
    fileprivate func insertSavedRowWithBlankCanonical(id: Int, title: String) throws {
        let row = CachedRecipe(
            id: id,
            slug: "blank-\(id)",
            title: title,
            excerptText: "",
            canonicalURLString: "",
            publishedAt: .now,
            isSaved: true
        )
        modelContext.insert(row)
        try modelContext.save()
    }
}
