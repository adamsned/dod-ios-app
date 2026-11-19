import Foundation
import Testing

@testable import DODSupport

@Suite("FireCircleCook") struct FireCircleCookTests {

    static func sample(endDate: Date? = Date(timeIntervalSince1970: 1_700_000_600)) -> FireCircleCook {
        FireCircleCook(
            peerID: "peer-1",
            cookName: "Sam",
            recipeTitle: "Brisket",
            stepText: "Rest the meat",
            remainingSeconds: 600,
            endDate: endDate,
            isPaused: false,
            isCompleted: false,
            sentAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    @Test func idIsPeerIDAndSchemaVersionDefaultsToCurrent() {
        let cook = Self.sample()
        #expect(cook.id == "peer-1")
        #expect(cook.schemaVersion == FireCircleCook.currentSchemaVersion)
    }

    @Test func encodedThenDecodeRoundTrips() throws {
        let cook = Self.sample()
        #expect(try FireCircleCook.decode(cook.encoded()) == cook)
    }

    @Test func roundTripPreservesNilEndDate() throws {
        let cook = Self.sample(endDate: nil)
        let decoded = try FireCircleCook.decode(cook.encoded())
        #expect(decoded == cook)
        #expect(decoded.endDate == nil)
    }

    @Test func decodeGarbageThrows() {
        #expect(throws: (any Error).self) {
            try FireCircleCook.decode(Data("not json".utf8))
        }
    }
}
