import DODSupport
import Foundation
import Testing

@testable import DODPersistence

@Suite("Cook-log occasion and recipient (DUT-994)")
struct CookLogOccasionTests {

    private static let cookedAt = Date(timeIntervalSince1970: 1_700_000_000)

    private func entry(id: UUID, recipeID: Int, occasion: CookOccasion, recipient: String?) -> CookLogEntry {
        CookLogEntry(
            id: id,
            recipeID: recipeID,
            recipeTitle: "Lasagna",
            cookedAt: Self.cookedAt,
            occasion: occasion,
            recipient: recipient
        )
    }

    /// A comfort cook entry round-trips through the store correctly.
    @Test func comfortEntryRoundTrips() async throws {
        let store = try await makeStore()

        let id = UUID()
        let entry = self.entry(id: id, recipeID: 1, occasion: .comfort, recipient: "Mom")
        try await store.logCook(entry)

        let logs = try await store.allCookLogs()
        #expect(logs.count == 1)
        #expect(logs.first?.occasion == .comfort)
        #expect(logs.first?.recipient == "Mom")
    }

    /// A legacy row (no occasion) reads as `.everyday`.
    @Test func legacyRowReadsAsEveryday() async throws {
        let store = try await makeStore()

        // Insert a legacy entry without an occasion
        let id = UUID()
        let entry = self.entry(id: id, recipeID: 1, occasion: .everyday, recipient: nil)
        try await store.logCook(entry)

        let logs = try await store.allCookLogs()
        #expect(logs.count == 1)
        #expect(logs.first?.occasion == .everyday)
        #expect(logs.first?.recipient == nil)
    }
}
