import DODSupport
import Foundation
import Testing

@testable import DODPersistence

/// DUT-593 (Low) — the ±3s dedup fetch in `logCook` used `try?`, so a fetch
/// error silently yielded `nil`, the dedup check was skipped, and a SECOND
/// `CachedCookLogEntry` was inserted for the same cook — silently defeating the
/// idempotency window (inflating streak / most-cooked stats). The fix uses `try`
/// so a fetch failure propagates instead of producing a duplicate. Driven via a
/// DEBUG-only per-actor dedup-fetch failpoint (an on-device fetch failure isn't
/// hermetically reproducible), mirroring the DUT-473 save-failpoint pattern.
@Suite("Cook-log dedup fetch error propagates (DUT-593)")
struct CookLogDedupFetchErrorTests {

    private static let cookedAt = Date(timeIntervalSince1970: 1_700_000_000)

    private struct FetchFailure: Error {}

    private func entry(recipeID: Int) -> CookLogEntry {
        CookLogEntry(
            id: UUID(),
            recipeID: recipeID,
            recipeTitle: "Chili",
            cookedAt: Self.cookedAt
        )
    }

    /// A throwing dedup fetch must PROPAGATE — not be swallowed into a silent
    /// duplicate insert.
    @Test func dedupFetchErrorPropagates() async throws {
        let store = try await makeStore()
        await store.setCookLogDedupFetchFailpointForTesting(FetchFailure())

        await #expect(throws: FetchFailure.self) {
            try await store.logCook(entry(recipeID: 1))
        }
    }

    /// When the fetch error propagates, NO cook row is inserted — the failed log
    /// leaves the journal untouched rather than adding a duplicate.
    @Test func noRowInsertedWhenDedupFetchThrows() async throws {
        let store = try await makeStore()

        // First cook succeeds.
        try await store.logCook(entry(recipeID: 5))
        #expect(try await store.allCookLogs().count == 1)

        // A retry within the ±3s window hits a throwing dedup fetch. Before the
        // fix, `try?` swallowed it and inserted a duplicate; now it throws and
        // inserts nothing.
        await store.setCookLogDedupFetchFailpointForTesting(FetchFailure())
        await #expect(throws: FetchFailure.self) {
            try await store.logCook(entry(recipeID: 5))
        }

        // Clear the failpoint: the journal still has exactly the one real cook.
        await store.setCookLogDedupFetchFailpointForTesting(nil)
        #expect(try await store.allCookLogs().count == 1)
    }
}
