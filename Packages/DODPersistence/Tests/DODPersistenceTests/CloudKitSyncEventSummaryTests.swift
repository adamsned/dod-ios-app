import Testing

@testable import DODPersistence

/// Unit coverage for the round-12 diagnostic formatter. The `init(event:)`
/// mapping is exercised at runtime on-device (an `NSPersistentCloudKitContainer
/// .Event` can't be constructed in a test), so these assert the pure
/// `logLine` rendering that the device logs will show.
@Suite("CloudKitSyncEventSummary")
struct CloudKitSyncEventSummaryTests {

    @Test func failedImportRendersPhaseDurationAndError() {
        let summary = CloudKitSyncEventSummary(
            phase: .importData,
            finished: true,
            succeeded: false,
            errorDescription: "Did not find any record types",
            durationSeconds: 1.5
        )
        #expect(
            summary.logLine
                == "CloudKit mirror import FAILED in 1.50s — Did not find any record types"
        )
    }

    @Test func succeededExportRendersOk() {
        let summary = CloudKitSyncEventSummary(
            phase: .export,
            finished: true,
            succeeded: true,
            errorDescription: nil,
            durationSeconds: 0.25
        )
        #expect(summary.logLine == "CloudKit mirror export ok in 0.25s")
    }

    @Test func inProgressStartEventHasNoStageDurationOrError() {
        let summary = CloudKitSyncEventSummary(
            phase: .setup,
            finished: false,
            succeeded: false,
            errorDescription: nil,
            durationSeconds: nil
        )
        #expect(summary.logLine == "CloudKit mirror setup started")
    }
}
