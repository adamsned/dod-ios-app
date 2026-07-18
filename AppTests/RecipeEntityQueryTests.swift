import DODDomain
import DODPersistence
import Foundation
import Testing

@testable import DODApp

/// Coverage for ``RecipeEntityQuery`` (US-10, DUT-406) — the Siri/Spotlight/
/// Shortcuts entity resolver. Zero prior coverage existed anywhere in the repo
/// (confirmed via grep) despite `suggestedPayloads(limit:)` implementing a
/// nontrivial three-pass budget-allocation algorithm.
///
/// Every expected id set below was hand-traced against the real algorithm
/// (not guessed): `recentsBudget = max(limit / 3, 1)`, then
/// `fill(saved, upTo: limit - recentsBudget)`, `fill(recents, upTo: limit)`,
/// `fill(saved, upTo: limit)`, deduping via a `seen: Set<Int>` as it goes.
///
/// `.serialized`: every test in this suite registers a fresh `RecipeStore`
/// into the shared, process-wide, `nonisolated(unsafe)` `AppIntentEnvironment`
/// static (see `AppTests/../App/AppIntentsSupport.swift`). Two tests racing
/// would let one test's store leak into another's assertions — the same
/// hazard the `Telemetry.shared`-touching suites (e.g.
/// `Packages/DODAnalytics/Tests/DODAnalyticsTests/TelemetryTests.swift`) guard
/// against with the same annotation. No OTHER suite in this test target
/// touches `AppIntentEnvironment` (grepped for it repo-wide before writing
/// this), so there is no cross-suite race to additionally guard against here.
@Suite("RecipeEntityQuery budget + search (US-10 / DUT-406)", .serialized)
struct RecipeEntityQueryTests {

    // MARK: - suggestedPayloads(limit:) boundary math

    /// `limit == 0`: `recentsBudget = max(0/3, 1) = 1`, so `cap = 0 - 1 = -1`.
    /// Every `fill` call's `out.count < cap` (or `< 0`) is false from the
    /// first element, so nothing is ever appended. Not a crash, just empty.
    @Test func limitZeroReturnsEmptyWithoutCrashing() async throws {
        let store = try await makeRegisteredStore()
        for id in 1...3 {
            try await store.cache(listItem: makeListItem(id: id, title: "Recipe \(id)"))
            try await store.markSaved(id: id)
        }

        let result = try await RecipeEntityQuery.suggestedPayloads(limit: 0)
        #expect(result.isEmpty, "limit 0 must return no payloads, not crash")
    }

    /// `limit == 1`: `recentsBudget = max(1/3, 1) = 1`, so `cap = 1 - 1 = 0`.
    /// The saved-fill pass is skipped entirely (cap 0), so the ENTIRE result
    /// comes from recents — even though 3 saved recipes exist, none surface.
    /// This is the `max(limit/3, 1)` floor working as designed, not a bug:
    /// it guarantees recents at least one slot, but at `limit == 1` that
    /// floor consumes the whole budget.
    @Test func limitOneWithRecentsAvailable_recentsWinTheOnlySlot() async throws {
        let store = try await makeRegisteredStore()
        for id in 1...3 {
            try await store.cache(listItem: makeListItem(id: id, title: "Saved \(id)"))
            try await store.markSaved(id: id)
        }
        // Cached after the saved rows, so these are the most recently viewed.
        for id in 4...5 {
            try await store.cache(listItem: makeListItem(id: id, title: "Recent \(id)"))
        }

        let result = try await RecipeEntityQuery.suggestedPayloads(limit: 1)
        let first = try #require(result.first)
        #expect(result.count == 1)
        #expect(first.id == 5, "the single most-recently-viewed row must win the only slot")
    }

    /// `limit == 1` again, but this time NOTHING else is cached besides the
    /// one saved recipe. `recentlyViewed(limit:)` reads ALL cached rows
    /// (saved and unsaved alike) — a saved recipe is necessarily cached
    /// first, so `recents` can never be genuinely EMPTY while a saved row
    /// exists against the real store. The lone recipe therefore surfaces via
    /// the recents-fill pass itself (not the trailing leftover-saved
    /// backfill) — `recentlyViewed(limit: 1)` simply returns that same row.
    /// A truly-empty `recents` (as the task brief's edge-case list poses it)
    /// would require `recentlyViewed` to throw so `try?` degrades it to
    /// `[]` — not reachable against `RecipeStore`, which isn't a fakeable
    /// protocol seam here, so that fault-injection path is out of scope.
    @Test func limitOneWithOnlyOneCachedRow_recentsFillPicksUpTheSoleSavedRecipe() async throws {
        let store = try await makeRegisteredStore()
        try await store.cache(listItem: makeListItem(id: 7, title: "Recipe 7"))
        try await store.markSaved(id: 7)

        let result = try await RecipeEntityQuery.suggestedPayloads(limit: 1)
        let first = try #require(result.first)
        #expect(result.count == 1)
        #expect(first.id == 7)
    }

    /// `limit == 9` ⇒ `recentsBudget == 3`, `cap == 6`. Saved count (5) is
    /// ONE BELOW the cap: every saved recipe fits in the first pass, and the
    /// recents-fill pass tops up the remaining 4 slots from the newest
    /// cached-but-unsaved rows.
    @Test func savedOneBelowCap_allSavedIncluded_recentsFillTheRemainder() async throws {
        let store = try await makeRegisteredStore()
        for id in 1...5 {
            try await store.cache(listItem: makeListItem(id: id, title: "Saved \(id)"))
            try await store.markSaved(id: id)
        }
        for id in 6...15 {
            try await store.cache(listItem: makeListItem(id: id, title: "Recent \(id)"))
        }

        let result = try await RecipeEntityQuery.suggestedPayloads(limit: 9)
        #expect(result.count == 9)
        #expect(Set(result.map(\.id)) == Set([1, 2, 3, 4, 5, 15, 14, 13, 12]))
    }

    /// Saved count lands EXACTLY at the cap (6): the saved-fill pass fills to
    /// precisely its budget with none left over, and recents fills the
    /// remaining 3 slots exactly.
    @Test func savedAtCapExactly_allSavedIncluded_recentsFillExactRemainder() async throws {
        let store = try await makeRegisteredStore()
        for id in 1...6 {
            try await store.cache(listItem: makeListItem(id: id, title: "Saved \(id)"))
            try await store.markSaved(id: id)
        }
        for id in 7...16 {
            try await store.cache(listItem: makeListItem(id: id, title: "Recent \(id)"))
        }

        let result = try await RecipeEntityQuery.suggestedPayloads(limit: 9)
        #expect(result.count == 9)
        #expect(Set(result.map(\.id)) == Set([1, 2, 3, 4, 5, 6, 16, 15, 14]))
    }

    /// Saved count is ONE ABOVE the cap (7 saved, cap 6) and recents are
    /// plentiful enough to fully consume the remaining budget. The
    /// saved-fill pass caps at 6 (dropping the 7th / oldest-saved recipe,
    /// id 1, from that pass), the recents-fill pass then completely fills
    /// the rest of `limit`, and the trailing leftover-saved backfill pass
    /// becomes a total no-op (`out.count < limit` is already false) — so
    /// id 1 is silently dropped from this suggestion batch entirely.
    ///
    /// This is the DUT-406-INTENDED tradeoff, not a bug: the recents-budget
    /// reservation is doing exactly its job (guaranteeing recents
    /// representation), at the cost of a saved recipe beyond the cap not
    /// appearing in THIS suggestion batch. The recipe is still saved and
    /// still shown in the Saved tab — only Siri/Spotlight suggestions omit
    /// it here.
    @Test
    func savedOneAboveCap_recentsFullyBackfillTheRemainder_oldestSavedRecipeIsDropped() async throws {
        let store = try await makeRegisteredStore()
        for id in 1...7 {
            try await store.cache(listItem: makeListItem(id: id, title: "Saved \(id)"))
            try await store.markSaved(id: id)
        }
        for id in 8...17 {
            try await store.cache(listItem: makeListItem(id: id, title: "Recent \(id)"))
        }

        let result = try await RecipeEntityQuery.suggestedPayloads(limit: 9)
        let ids = result.map(\.id)
        #expect(result.count == 9)
        #expect(!ids.contains(1), "the oldest saved recipe beyond the cap is dropped when recents fully backfill")
        #expect(Set(ids) == Set([7, 6, 5, 4, 3, 2, 17, 16, 15]))
    }

    /// Same saved-one-above-cap setup (7 saved, cap 6), but this time only
    /// ONE extra unsaved row exists — so the store has 8 cached rows total.
    /// `recentlyViewed(limit: 9)` (called for the recents-fill pass) reads
    /// EVERY cached row, which includes the still-uncounted saved id 1 — so
    /// the recents-fill pass itself ends up recovering it (via
    /// `recentlyViewed`, not the trailing leftover-saved pass, since the
    /// leftover pass finds every saved id already in `seen` by that point).
    /// The net effect proven here: with a small store, a saved recipe
    /// dropped by the first pass is NOT permanently starved — it resurfaces
    /// because recents naturally overlaps saved. Only 8 total distinct
    /// recipes exist, so the limit of 9 cannot be fully reached.
    @Test
    func savedOneAboveCap_smallStore_recentsPassRecoversThePreviouslyDroppedRecipe() async throws {
        let store = try await makeRegisteredStore()
        for id in 1...7 {
            try await store.cache(listItem: makeListItem(id: id, title: "Saved \(id)"))
            try await store.markSaved(id: id)
        }
        try await store.cache(listItem: makeListItem(id: 100, title: "Recent 100"))

        let result = try await RecipeEntityQuery.suggestedPayloads(limit: 9)
        #expect(result.count == 8, "only 8 distinct recipes exist, so 9 can never be reached")
        #expect(Set(result.map(\.id)) == Set([7, 6, 5, 4, 3, 2, 100, 1]), "id 1 must be recovered, not starved")
    }

    /// Saved is EMPTY, recents has plenty. The recents-fill pass's cap is
    /// `limit`, not `recentsBudget` — so with no saved competition, recents
    /// fills the WHOLE limit, not just its reserved third. Proves
    /// `recentsBudget` is a floor/minimum reservation, never a ceiling.
    @Test func savedEmpty_recentsFillTheEntireLimit_noGapFromTheBudgetReservation() async throws {
        let store = try await makeRegisteredStore()
        for id in 1...12 {
            try await store.cache(listItem: makeListItem(id: id, title: "Recent \(id)"))
        }

        let result = try await RecipeEntityQuery.suggestedPayloads(limit: 9)
        #expect(result.count == 9)
        #expect(Set(result.map(\.id)) == Set([12, 11, 10, 9, 8, 7, 6, 5, 4]))
    }

    // MARK: - entities(matching:)

    @Test func entitiesMatchingIsCaseInsensitiveSubstringMatch() async throws {
        let store = try await makeRegisteredStore()
        for (id, title) in titledFixtures {
            try await store.cache(listItem: makeListItem(id: id, title: title))
        }

        let result = try await RecipeEntityQuery().entities(matching: "BOURBON")
        let first = try #require(result.first)
        #expect(result.count == 1)
        #expect(first.id == 1)
        #expect(first.title == "Bourbon Berry Cake")
    }

    /// Empirically verified (NOT the naive assumption from just reading the
    /// source): with `Foundation` imported — as `RecipeEntity.swift` does —
    /// `String.contains(_:)` resolves to Foundation's `NSString`-bridged
    /// range-search overload, which treats an EMPTY needle as "not found"
    /// (mirrors `NSString.range(of: "").location == NSNotFound`), NOT the
    /// pure stdlib `Collection.contains` semantics (which would say every
    /// string trivially contains the empty one). Confirmed with a minimal
    /// `import Foundation; "x".contains("")` repro outside this test target:
    /// `false` — the opposite of the pure-stdlib answer (`true` with no
    /// Foundation import). So a blank Siri transcription matches NOTHING
    /// here, not "everything" — arguably the more sensible outcome for a
    /// search feature, and not reachable in practice (Siri won't hand this
    /// method a blank transcription), but worth pinning since it inverts
    /// what the source reads like it should do.
    @Test func entitiesMatchingEmptyStringMatchesNothing() async throws {
        let store = try await makeRegisteredStore()
        for (id, title) in titledFixtures {
            try await store.cache(listItem: makeListItem(id: id, title: title))
        }

        let result = try await RecipeEntityQuery().entities(matching: "")
        #expect(result.isEmpty, "Foundation's contains(\"\") is false, so a blank query matches nothing")
    }

    // MARK: - entities(for identifiers:)

    /// A per-id fetch failure (here, a nonexistent id) must be silently
    /// skipped via the production code's `try?` — not fail the whole batch.
    @Test func entitiesForIdentifiersSkipsMissingIdsWithoutFailingTheWholeBatch() async throws {
        let store = try await makeRegisteredStore()
        try await store.cache(listItem: makeListItem(id: 1, title: "Found Recipe"))
        try await store.markSaved(id: 1)

        let result = try await RecipeEntityQuery().entities(for: [1, 999])
        let first = try #require(result.first)
        #expect(result.count == 1)
        #expect(first.id == 1)
    }

    @Test func entitiesForIdentifiersReturnsEmptyWhenNoneOfTheIdsExist() async throws {
        let store = try await makeRegisteredStore()
        try await store.cache(listItem: makeListItem(id: 1, title: "Found Recipe"))
        try await store.markSaved(id: 1)

        let result = try await RecipeEntityQuery().entities(for: [777, 888])
        #expect(result.isEmpty)
    }
}

// MARK: - Helpers

private let titledFixtures: [(id: Int, title: String)] = [
    (1, "Bourbon Berry Cake"),
    (2, "Classic Cornbread"),
    (3, "Dutch Oven Chili"),
]

private func makeRegisteredStore() async throws -> RecipeStore {
    let container = try RecipeStore.inMemoryContainer()
    let store = RecipeStore(modelContainer: container)
    AppIntentEnvironment.register(store: store)
    return store
}

private func makeListItem(id: Int, title: String) -> RecipeListItem {
    RecipeListItem(
        id: id,
        title: title,
        excerpt: "An excerpt.",
        heroImage: URL(string: "https://example.com/\(id).jpg"),
        publishedAt: Date(timeIntervalSince1970: 1_700_000_000 + TimeInterval(id)),
        totalTimeDisplay: nil
    )
}
