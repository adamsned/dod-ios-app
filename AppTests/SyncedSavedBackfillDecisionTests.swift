import XCTest

@testable import DODApp

/// DUT-468 — the launch synced-saved backfill must SEED legacy pins unless a
/// CloudKit import proved another ≥V5 device already owns the saved set. The
/// decision is pure set arithmetic over three snapshots: the pre-import
/// baseline of synced ids, the post-import synced ids, and the locally-pinned
/// ids. A save made DURING the import wait writes a synced row too, so a naive
/// "any synced row exists" check (the DUT-240 original) would wrongly skip the
/// seed and permanently strand every other legacy pin. These pin the fix.
final class SyncedSavedBackfillDecisionTests: XCTestCase {

    /// First ≥V5 device, no remote saves, nothing happened during the wait →
    /// seed.
    func testEmptyEverywhereSeeds() {
        XCTAssertTrue(
            AppDependencies.shouldSeedAfterImport(
                baselineSyncedIDs: [],
                currentSyncedIDs: [],
                locallyPinnedIDs: []
            )
        )
    }

    /// The regression: the user saves a recipe during the 20s import wait. That
    /// writes a synced row (id 5) AND its local pin, but no remote row arrived.
    /// The seed must still run so the OTHER legacy pins migrate.
    func testLocalSaveDuringWaitDoesNotBlockSeed() {
        XCTAssertTrue(
            AppDependencies.shouldSeedAfterImport(
                baselineSyncedIDs: [],
                currentSyncedIDs: [5],
                locallyPinnedIDs: [5]
            )
        )
    }

    /// A genuine remote import: id 7 arrived with a synced row but NO local pin
    /// (mergeDetail hasn't run for it). Another device owns the set → skip the
    /// seed so local-only legacy pins aren't resurrected as cross-device saves.
    func testImportDeliveredRowSkipsSeed() {
        XCTAssertFalse(
            AppDependencies.shouldSeedAfterImport(
                baselineSyncedIDs: [],
                currentSyncedIDs: [7],
                locallyPinnedIDs: []
            )
        )
    }

    /// Mixed: a remote row (7, no pin) AND a local save during the wait (5,
    /// pinned). The remote row still forces a skip — the set is authoritative.
    func testRemoteRowWinsOverConcurrentLocalSave() {
        XCTAssertFalse(
            AppDependencies.shouldSeedAfterImport(
                baselineSyncedIDs: [],
                currentSyncedIDs: [5, 7],
                locallyPinnedIDs: [5]
            )
        )
    }

    /// Rows already present at launch (baseline) are not import evidence — a
    /// prior session's own saves shouldn't be read as another device's set.
    func testBaselineRowsAreNotImportEvidence() {
        XCTAssertTrue(
            AppDependencies.shouldSeedAfterImport(
                baselineSyncedIDs: [3],
                currentSyncedIDs: [3],
                locallyPinnedIDs: []
            )
        )
    }
}
