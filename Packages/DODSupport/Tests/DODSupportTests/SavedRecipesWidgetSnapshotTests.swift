import Foundation
import Testing

@testable import DODSupport

/// Round-trip tests for the snapshot the main app writes for the
/// saved-recipes widget extension. Mirrors `WidgetSnapshotTests` — both
/// snapshots use the same App Group / UserDefaults pattern, so the same
/// canary applies: if the encoder here doesn't match the decoder over
/// there the home-screen widget shows the placeholder forever.
///
/// Spec trace: spec.md US-17, AC-17.3 (snapshot payload), AC-17.6 (schema
/// versioning + clear behavior), AC-17.8 (L1 cases).
@Suite("SavedRecipesWidgetSnapshotStore round-trip") struct SavedRecipesWidgetSnapshotStoreTests {

    @Test func writeThenReadReturnsTheSameEntries() throws {
        let defaults = try Self.freshDefaults()
        let store = WidgetSnapshotStore(defaults: defaults)
        let entries = Self.sampleEntries(count: 3)

        let writtenAt = Date(timeIntervalSince1970: 1_700_000_000)
        try store.writeSavedRecipes(
            SavedRecipesWidgetSnapshot(writtenAt: writtenAt, entries: entries)
        )

        let roundTripped = try #require(store.readSavedRecipes())
        #expect(roundTripped.schemaVersion == SavedRecipesWidgetSnapshot.currentSchemaVersion)
        #expect(roundTripped.writtenAt == writtenAt)
        #expect(roundTripped.entries == entries)
    }

    @Test func writeWithEntriesConvenienceCapsAtMaxEntries() throws {
        let defaults = try Self.freshDefaults()
        let store = WidgetSnapshotStore(defaults: defaults)
        // Build 10 entries with strictly increasing `savedAt` so the
        // sort-by-recency rule has a determinate answer.
        let entries = Self.sampleEntries(count: 10)

        try store.writeSavedRecipes(entries: entries)

        let roundTripped = try #require(store.readSavedRecipes())
        #expect(roundTripped.entries.count == SavedRecipesWidgetSnapshotConfig.maxEntries)
        // Per AC-17.3 the snapshot carries the N (= maxEntries) most-recently-
        // saved recipes. Sample entries have savedAt = base + index, so the
        // most-recently-saved are the highest indices in descending order.
        // Derived from `maxEntries` so the T-768 cap bump (3 → 5) didn't
        // require a hand-edit here.
        let expectedIDs = Array(
            (1...10).reversed().prefix(SavedRecipesWidgetSnapshotConfig.maxEntries)
        )
        #expect(roundTripped.entries.map(\.recipeID) == expectedIDs)
    }

    @Test func writeSortsByMostRecentlySavedFirst() throws {
        let defaults = try Self.freshDefaults()
        let store = WidgetSnapshotStore(defaults: defaults)
        // Hand the writer an out-of-order list — it must sort before
        // capping so the widget never shows a stale-but-recent entry just
        // because the caller passed entries in insertion order.
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let shuffled: [SavedRecipesWidgetSnapshot.Entry] = [
            Self.entry(recipeID: 1, savedAt: base.addingTimeInterval(10)),
            Self.entry(recipeID: 2, savedAt: base.addingTimeInterval(100)),
            Self.entry(recipeID: 3, savedAt: base.addingTimeInterval(50)),
        ]

        try store.writeSavedRecipes(entries: shuffled)

        let roundTripped = try #require(store.readSavedRecipes())
        #expect(roundTripped.entries.map(\.recipeID) == [2, 3, 1])
    }

    @Test func readReturnsNilWhenNothingWritten() throws {
        let defaults = try Self.freshDefaults()
        let store = WidgetSnapshotStore(defaults: defaults)
        #expect(store.readSavedRecipes() == nil)
    }

    @Test func readReturnsNilOnVersionMismatch() throws {
        let defaults = try Self.freshDefaults()
        let store = WidgetSnapshotStore(defaults: defaults)
        // Simulate a payload written by a future binary that bumped the
        // schemaVersion. The current binary must refuse to decode it
        // (returns nil) so the widget falls back to the placeholder rather
        // than rendering partial garbage — same contract as
        // `WidgetSnapshotStore.read()` on the featured widget.
        let future = SavedRecipesWidgetSnapshot(
            schemaVersion: 99,
            writtenAt: Date(),
            entries: Self.sampleEntries(count: 1)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        defaults.set(
            try encoder.encode(future),
            forKey: SavedRecipesWidgetSnapshotConfig.userDefaultsKey
        )

        #expect(store.readSavedRecipes() == nil)
    }

    @Test func clearRemovesPersistedPayload() throws {
        let defaults = try Self.freshDefaults()
        let store = WidgetSnapshotStore(defaults: defaults)
        try store.writeSavedRecipes(entries: Self.sampleEntries(count: 2))
        #expect(store.readSavedRecipes() != nil)
        store.clearSavedRecipes()
        #expect(store.readSavedRecipes() == nil)
    }

    @Test func savedAndFeaturedPayloadsDoNotCollide() throws {
        // Both widgets share one App Group / UserDefaults suite. Writing
        // one must never overwrite the other's payload — guard the
        // distinct-keys contract here so a future refactor can't silently
        // unify them.
        let defaults = try Self.freshDefaults()
        let store = WidgetSnapshotStore(defaults: defaults)

        let featuredEntry = WidgetSnapshot.Entry(
            id: 42,
            title: "Featured",
            excerpt: "x",
            heroImageURL: nil,
            canonicalURL: nil,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: nil
        )
        try store.write(entries: [featuredEntry])
        try store.writeSavedRecipes(entries: Self.sampleEntries(count: 1))

        #expect(store.read()?.entries.first?.id == 42)
        #expect(store.readSavedRecipes()?.entries.first?.recipeID == 1)
    }

    // MARK: - Helpers

    private static func freshDefaults() throws -> UserDefaults {
        // Per-test suite name keeps tests parallel-safe — never touches
        // `.standard` or the real App Group.
        let name = "dod.widget.saved.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private static func sampleEntries(count: Int) -> [SavedRecipesWidgetSnapshot.Entry] {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        return (1...count).map { index in
            entry(recipeID: index, savedAt: base.addingTimeInterval(TimeInterval(index)))
        }
    }

    /// Test fixture URL builder. Returns a non-optional URL so the test
    /// surface is ergonomic; uses `URL(string:relativeTo:)` against a
    /// known-good base instead of force-unwrapping a literal (swiftlint
    /// `force_unwrapping` rule is project policy).
    private static func canonicalURL(for recipeID: Int) -> URL {
        let base =
            URL(string: "https://www.dutchovendaddy.com/")
            ?? URL(fileURLWithPath: "/")
        return URL(string: "recipe-\(recipeID)/", relativeTo: base)?.absoluteURL
            ?? base
    }

    private static func entry(
        recipeID: Int,
        savedAt: Date
    ) -> SavedRecipesWidgetSnapshot.Entry {
        SavedRecipesWidgetSnapshot.Entry(
            recipeID: recipeID,
            title: "Saved Recipe \(recipeID)",
            canonicalURL: canonicalURL(for: recipeID),
            heroImageFilename: "hero-\(recipeID).jpg",
            savedAt: savedAt
        )
    }
}

/// DUT — `SavedRecipesWidgetSnapshot.Entry.deepLinkURL` backs
/// `SavedRecipesWidgetEntryView`'s tap-through URL. WidgetKit's
/// `placeholder(in:)` / `getSnapshot(in:)` calls can render
/// `SavedRecipesEntry.placeholder`'s fabricated preview rows (fictional
/// titles like "Garlic Butter Skillet Corn") in a tappable transient state
/// before the real snapshot loads; those rows must never resolve to a real,
/// well-formed `dod://recipe/<id>` link, or a tap would silently open
/// whatever unrelated real post happens to share that id instead of falling
/// back to the Saved tab. Mirrors the `id > 0` guard
/// `FeaturedRecipeWidgetEntryView.deepLink(for:)` already applies to its own
/// placeholder (DUT-652).
@Suite("SavedRecipesWidgetSnapshot.Entry.deepLinkURL")
struct SavedRecipesEntryDeepLinkURLTests {

    private func entry(recipeID: Int) -> SavedRecipesWidgetSnapshot.Entry {
        SavedRecipesWidgetSnapshot.Entry(
            recipeID: recipeID,
            title: "Some Recipe",
            canonicalURL: URL(fileURLWithPath: "/"),
            heroImageFilename: nil,
            savedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    @Test func positiveIDBuildsARecipeLinkWithSavedSource() throws {
        let url = try #require(entry(recipeID: 4641).deepLinkURL)
        #expect(WidgetDeepLinkParser.parse(url) == .recipe(id: 4641, source: .saved))
    }

    /// A non-positive id — the shape `SavedRecipesEntry.placeholder`'s
    /// fabricated rows use — must not resolve to any deep link at all, so
    /// callers fall through to their own `dod://saved` fallback instead of
    /// silently opening whatever real post happens to share that id.
    @Test func nonPositiveIDReturnsNil() {
        #expect(entry(recipeID: 0).deepLinkURL == nil)
        #expect(entry(recipeID: -1).deepLinkURL == nil)
        #expect(entry(recipeID: -3).deepLinkURL == nil)
    }
}
