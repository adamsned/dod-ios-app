import Foundation
import Testing

@testable import DODSupport

/// Round-trip tests for the snapshot the main app writes for the widget
/// extension. Both processes use ``WidgetSnapshotStore`` — if the encoder
/// here doesn't match the decoder over there the home-screen widget shows
/// the placeholder forever, so this is the canary.
///
/// Spec trace: spec.md US-9 widget data flow, REG-9.
@Suite("WidgetSnapshotStore round-trip") struct WidgetSnapshotStoreTests {

    @Test func writeThenReadReturnsTheSameEntries() throws {
        let defaults = try Self.freshDefaults()
        let store = WidgetSnapshotStore(defaults: defaults, key: "test.payload")
        let entries = Self.sampleEntries(count: 3)

        let writtenAt = Date(timeIntervalSince1970: 1_700_000_000)
        try store.write(WidgetSnapshot(writtenAt: writtenAt, entries: entries))

        let roundTripped = try #require(store.read())
        #expect(roundTripped.version == WidgetSnapshot.currentVersion)
        #expect(roundTripped.writtenAt == writtenAt)
        #expect(roundTripped.entries == entries)
    }

    // DUT-460 — the adaptive-eyebrow flag round-trips, and a legacy payload
    // written before the field decodes to `false` (recipe) instead of throwing.
    @Test func isArticleRoundTripsAndDefaultsForLegacyPayloads() throws {
        let article = WidgetSnapshot.Entry(
            id: 7,
            title: "Best Dutch Oven Roundups",
            excerpt: "e",
            heroImageURL: nil,
            canonicalURL: nil,
            publishedAt: Date(timeIntervalSince1970: 1),
            totalTimeDisplay: nil,
            isArticle: true
        )
        let data = try JSONEncoder().encode(article)
        #expect(try JSONDecoder().decode(WidgetSnapshot.Entry.self, from: data).isArticle)

        // Strip the key to simulate a pre-DUT-460 payload → must default false.
        var json = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        json.removeValue(forKey: "isArticle")
        let legacyData = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(WidgetSnapshot.Entry.self, from: legacyData)
        #expect(decoded.isArticle == false)
    }

    // DUT-485 / T-905 — the "Latest" widget's latestRecipe / latestArticle
    // fields round-trip through the store.
    @Test func latestRecipeAndArticleRoundTrip() throws {
        let defaults = try Self.freshDefaults()
        let store = WidgetSnapshotStore(defaults: defaults, key: "test.latestSplit")
        let entries = Self.sampleEntries(count: 3)
        let recipe = entries[0]
        let article = WidgetSnapshot.Entry(
            id: 99,
            title: "Best Dutch Oven Roundups",
            excerpt: "An article, not a recipe.",
            heroImageURL: nil,
            canonicalURL: nil,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_500),
            totalTimeDisplay: nil,
            isArticle: true
        )

        try store.write(entries: entries, latestRecipe: recipe, latestArticle: article)

        let read = try #require(store.read())
        #expect(read.latestRecipe == recipe)
        #expect(read.latestArticle == article)
        #expect(read.latestArticle?.isArticle == true)
        #expect(read.entries == entries)
    }

    // DUT-485 / T-905 — a payload written before latestRecipe/latestArticle
    // existed decodes with both fields nil rather than throwing (back-compat).
    @Test func snapshotDecodesLegacyPayloadWithoutLatestSplitFields() throws {
        let defaults = try Self.freshDefaults()
        let key = "test.preDUT485"
        let legacyPayload: [String: Any] = [
            "version": WidgetSnapshot.currentVersion,
            "writtenAt": "2024-01-01T00:00:00Z",
            "entries": [
                [
                    "id": 7,
                    "title": "Legacy entry",
                    "excerpt": "Excerpt",
                    "publishedAt": "2024-01-01T00:00:00Z",
                ]
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: legacyPayload)
        defaults.set(data, forKey: key)
        let store = WidgetSnapshotStore(defaults: defaults, key: key)

        let read = try #require(store.read())
        #expect(read.entries.first?.id == 7)
        #expect(read.latestRecipe == nil)
        #expect(read.latestArticle == nil)
    }

    // DUT-485 / T-905 — the legacy convenience overload defaults both split
    // fields to nil so existing call sites keep behaving.
    @Test func legacyWriteEntriesConvenienceLeavesLatestSplitNil() throws {
        let defaults = try Self.freshDefaults()
        let store = WidgetSnapshotStore(defaults: defaults, key: "test.legacyConvenience")
        try store.write(entries: Self.sampleEntries(count: 2))
        let read = try #require(store.read())
        #expect(read.latestRecipe == nil)
        #expect(read.latestArticle == nil)
    }

    @Test func writeWithEntriesConvenienceCapsAtMaxEntries() throws {
        let defaults = try Self.freshDefaults()
        let store = WidgetSnapshotStore(defaults: defaults, key: "test.cap")
        let entries = Self.sampleEntries(count: 12)

        try store.write(entries: entries)

        let roundTripped = try #require(store.read())
        #expect(roundTripped.entries.count == WidgetSnapshotConfig.maxEntries)
        // First N preserved in input order — the writer cap must take from
        // the head, not a random window.
        let expectedIDs = Array(entries.prefix(WidgetSnapshotConfig.maxEntries)).map(\.id)
        #expect(roundTripped.entries.map(\.id) == expectedIDs)
    }

    @Test func readReturnsNilWhenNothingWritten() throws {
        let defaults = try Self.freshDefaults()
        let store = WidgetSnapshotStore(defaults: defaults, key: "test.empty")
        #expect(store.read() == nil)
    }

    @Test func readReturnsNilOnVersionMismatch() throws {
        let defaults = try Self.freshDefaults()
        let key = "test.versionDrift"
        let store = WidgetSnapshotStore(defaults: defaults, key: key)
        // Simulate a payload written by a future binary that bumped the
        // version. The current binary must refuse to decode it (returns nil)
        // so the widget falls back to the placeholder rather than rendering
        // partial garbage.
        let future = WidgetSnapshot(
            version: WidgetSnapshot.currentVersion + 1,
            writtenAt: Date(),
            entries: Self.sampleEntries(count: 1)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        defaults.set(try encoder.encode(future), forKey: key)

        #expect(store.read() == nil)
    }

    @Test func clearRemovesPersistedPayload() throws {
        let defaults = try Self.freshDefaults()
        let store = WidgetSnapshotStore(defaults: defaults, key: "test.clear")
        try store.write(entries: Self.sampleEntries(count: 2))
        #expect(store.read() != nil)
        store.clear()
        #expect(store.read() == nil)
    }

    // MARK: - US-21 / T-360 — heroImageFilename additive field

    @Test func entryRoundTripsHeroImageFilename() throws {
        let defaults = try Self.freshDefaults()
        let store = WidgetSnapshotStore(defaults: defaults, key: "test.heroFilename")
        let entry = WidgetSnapshot.Entry(
            id: 42,
            title: "Hero filename test",
            excerpt: "An excerpt.",
            heroImageURL: URL(string: "https://example.com/img.jpg"),
            canonicalURL: URL(string: "https://example.com/recipe-42/"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: "10 min",
            heroImageFilename: "abc123.img"
        )
        try store.write(WidgetSnapshot(writtenAt: Date(), entries: [entry]))
        let read = try #require(store.read())
        #expect(read.entries.first?.heroImageFilename == "abc123.img")
    }

    @Test func entryDecodesPayloadFromPreUS21WriterWithoutFilenameField() throws {
        // Older host binaries (pre-US-21) wrote the entry without the
        // `heroImageFilename` field. The new decoder must default the
        // missing field to nil rather than refusing the payload — the
        // widget can still render via the gradient placeholder for those
        // entries, but the surrounding entry data (title, excerpt, etc.)
        // must still come through cleanly.
        let defaults = try Self.freshDefaults()
        let key = "test.preUS21"
        // Build the payload by hand without the `heroImageFilename` key.
        let legacyPayload: [String: Any] = [
            "version": WidgetSnapshot.currentVersion,
            "writtenAt": "2024-01-01T00:00:00Z",  // ISO-8601, no fractional seconds
            "entries": [
                [
                    "id": 7,
                    "title": "Legacy entry",
                    "excerpt": "Excerpt",
                    "publishedAt": "2024-01-01T00:00:00Z",
                ]
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: legacyPayload)
        defaults.set(data, forKey: key)
        let store = WidgetSnapshotStore(defaults: defaults, key: key)
        let read = try #require(store.read())
        let firstEntry = try #require(read.entries.first)
        #expect(firstEntry.id == 7)
        #expect(firstEntry.title == "Legacy entry")
        #expect(firstEntry.heroImageFilename == nil)
        #expect(firstEntry.heroImageURL == nil)
    }

    @Test func entryWithFilenameMatchesBridgeFilenameForURL() throws {
        // Sanity: when the writer populates `heroImageFilename` from
        // `WidgetImageBridge.filename(for:)`, the round-tripped value is
        // exactly what the widget consumer expects to resolve against
        // the App Group container.
        let url = try #require(URL(string: "https://www.dutchovendaddy.com/img.jpg"))
        let expected = WidgetImageBridge.filename(for: url)
        let entry = WidgetSnapshot.Entry(
            id: 1,
            title: "x",
            excerpt: "x",
            heroImageURL: url,
            canonicalURL: nil,
            publishedAt: Date(),
            totalTimeDisplay: nil,
            heroImageFilename: expected
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let roundTripped = try decoder.decode(WidgetSnapshot.Entry.self, from: data)
        #expect(roundTripped.heroImageFilename == expected)
    }

    // MARK: - Helpers

    private static func freshDefaults() throws -> UserDefaults {
        // Per-test suite name keeps tests parallel-safe — never touches
        // `.standard`.
        let name = "dod.widget.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private static func sampleEntries(count: Int) -> [WidgetSnapshot.Entry] {
        (1...count).map { index in
            WidgetSnapshot.Entry(
                id: index,
                title: "Recipe \(index)",
                excerpt: "Excerpt for recipe \(index).",
                heroImageURL: URL(string: "https://www.dutchovendaddy.com/wp-content/uploads/\(index).jpg"),
                canonicalURL: URL(string: "https://www.dutchovendaddy.com/recipe-\(index)/"),
                publishedAt: Date(timeIntervalSince1970: 1_700_000_000 + TimeInterval(index)),
                totalTimeDisplay: "\(15 + index) min"
            )
        }
    }
}
