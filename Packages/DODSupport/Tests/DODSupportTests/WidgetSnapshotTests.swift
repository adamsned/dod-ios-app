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
