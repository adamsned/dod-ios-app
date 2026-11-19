import Foundation
import Testing

@testable import DODSupport

@Suite("DinerReaction (DUT-996)")
struct DinerReactionTests {
    @Test("reactionCountsAsTried")
    func reactionCountsAsTried() {
        #expect(!OneBiteReaction.notYet.countsAsTried)
        #expect(OneBiteReaction.tried.countsAsTried)
        #expect(OneBiteReaction.liked.countsAsTried)
    }

    @Test("entryRoundTripsThroughJSON")
    func entryRoundTripsThroughJSON() throws {
        let entry = DinerReactionEntry(
            dinerKey: "diner123",
            dinerName: "John Doe",
            recipeID: 456,
            recipeTitle: "Delicious Pasta",
            reaction: .liked,
            loggedAt: Date()
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(entry)
        let decoded = try decoder.decode(DinerReactionEntry.self, from: data)

        #expect(decoded == entry)
    }
}
