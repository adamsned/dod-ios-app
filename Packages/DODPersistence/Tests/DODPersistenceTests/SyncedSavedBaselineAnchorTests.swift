import DODDomain
import Foundation
import SwiftData
import Testing

@testable import DODPersistence

/// DUT-494 — the synced-saved baseline the launch backfill subtracts must be
/// anchored to PROCESS-START state, before the CloudKit import engine can
/// deliver another device's rows. `AppDependencies.init` reads it via the
/// synchronous, container-scoped ``RecipeStore/syncedSavedIDSet(in:)`` for
/// exactly this reason: the actor-isolated read can only run later and could
/// see a fast/warm import's rows already merged in.
///
/// These tests pin the reader's contract that makes the anchor poison-proof:
/// it sees the same container's rows, and a baseline captured BEFORE a later
/// insert does NOT include that insert (the model for "an import that lands
/// after the anchor still counts as import evidence, not baseline").
@Suite("Synced-saved baseline anchor (DUT-494)")
struct SyncedSavedBaselineAnchorTests {

    private func url(_ string: String) -> URL {
        URL(string: string) ?? URL(filePath: "/dev/null")
    }

    private func sampleListItem(id: Int) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: "Recipe \(id)",
            excerpt: "Excerpt",
            heroImage: url("https://dutchovendaddy.com/\(id).jpg"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: nil,
            canonicalURL: url("https://dutchovendaddy.com/\(id)")
        )
    }

    /// The synchronous reader sees rows already on disk (a prior session's
    /// saves) — the legitimate non-empty baseline that must NOT read as import
    /// evidence (mirrors the App `testBaselineRowsAreNotImportEvidence` case).
    @Test func readsRowsAlreadyPresentAtCapture() async throws {
        let container = try RecipeStore.inMemoryContainer()
        let store = RecipeStore(modelContainer: container)
        try await store.cache(listItem: sampleListItem(id: 3))
        _ = try await store.toggleSaved(id: 3)

        let baseline = try RecipeStore.syncedSavedIDSet(in: container)
        #expect(baseline == [3])
    }

    /// The anchor is the DUT-494 fix: a baseline captured BEFORE a later insert
    /// does not contain it. This is precisely why capturing in `init` (pre run
    /// loop, pre-import) beats the old `.task`-time read — an import landing
    /// AFTER the anchor stays visible as `current − baseline` import evidence
    /// (→ skip the seed) instead of being poisoned into the baseline (→ wrong
    /// seed). Here `toggleSaved(id: 7)` stands in for that post-anchor import.
    @Test func baselineTakenBeforeAnInsertExcludesIt() async throws {
        let container = try RecipeStore.inMemoryContainer()
        let store = RecipeStore(modelContainer: container)

        // Anchor the baseline on a fresh store — empty, as on a first-launch
        // upgrader before any import lands.
        let baseline = try RecipeStore.syncedSavedIDSet(in: container)
        #expect(baseline.isEmpty)

        // Device B's row 7 "imports" AFTER the anchor.
        try await store.cache(listItem: sampleListItem(id: 7))
        _ = try await store.toggleSaved(id: 7)

        // Post-import current set now has 7; because it was NOT folded into the
        // baseline, `current − baseline` retains 7 as import evidence.
        let current = try await store.syncedSavedIDSet()
        #expect(current == [7])
        #expect(current.subtracting(baseline) == [7])
    }
}
