import DODSupport
import Foundation
import Testing

@testable import DODPersistence

/// DUT-975 — test that confidence round-trips through log and update.
@Suite("Cook-log confidence (DUT-975)")
struct CookLogConfidenceTests {

    private static let cookedAt = Date(timeIntervalSince1970: 1_700_000_000)

    private func entry(id: UUID, recipeID: Int, photoLocalID: String?, confidence: Int?) -> CookLogEntry {
        CookLogEntry(
            id: id,
            recipeID: recipeID,
            recipeTitle: "Lasagna",
            cookedAt: Self.cookedAt,
            photoLocalID: photoLocalID,
            confidence: confidence
        )
    }

    /// The confidence value should round-trip through log and update.
    @Test func confidenceRoundTripsThroughLogAndUpdate() async throws {
        let store = try await makeStore()

        // Log a cook with confidence 2
        let id = UUID()
        try await store.logCook(entry(id: id, recipeID: 1, photoLocalID: nil, confidence: 2))

        // Check that it was logged with confidence 2
        let logs = try await store.allCookLogs()
        #expect(logs.count == 1)
        #expect(logs.first?.confidence == 2)

        // Update the cook with confidence 4
        var updatedEntry = entry(id: id, recipeID: 1, photoLocalID: nil, confidence: 4)
        try await store.updateCookLog(updatedEntry)

        // Check that it was updated to confidence 4
        let updatedLogs = try await store.allCookLogs()
        #expect(updatedLogs.count == 1)
        #expect(updatedLogs.first?.confidence == 4)
    }
}
