import Testing
import XCTest

@testable import DODSupport

@Suite struct ConfidenceChallengeBiasTests {

    @Test func noReadsReturnsSame() {
        let entries: [CookLogEntry] = []
        let result = ConfidenceChallengeBias.bias(for: entries)
        #expect(result == .same)
    }

    @Test func oneOrTwoReadsReturnsEasier() {
        let entries = [
            CookLogEntry(id: UUID(), recipeID: 1, recipeTitle: "Test", cookedAt: Date(), confidence: 1),
            CookLogEntry(id: UUID(), recipeID: 2, recipeTitle: "Test2", cookedAt: Date(), confidence: 2),
        ]
        let result = ConfidenceChallengeBias.bias(for: entries)
        #expect(result == .easier)
    }

    @Test func threeReadsAllFourOrFiveReturnsHarder() {
        let entries = [
            CookLogEntry(id: UUID(), recipeID: 1, recipeTitle: "Test", cookedAt: Date(), confidence: 4),
            CookLogEntry(id: UUID(), recipeID: 2, recipeTitle: "Test2", cookedAt: Date(), confidence: 5),
            CookLogEntry(id: UUID(), recipeID: 3, recipeTitle: "Test3", cookedAt: Date(), confidence: 5),
        ]
        let result = ConfidenceChallengeBias.bias(for: entries)
        #expect(result == .harder)
    }

    @Test func threeReadsAverageThreeOrFourReturnsSame() {
        let entries = [
            CookLogEntry(id: UUID(), recipeID: 1, recipeTitle: "Test", cookedAt: Date(), confidence: 3),
            CookLogEntry(id: UUID(), recipeID: 2, recipeTitle: "Test2", cookedAt: Date(), confidence: 3),
            CookLogEntry(id: UUID(), recipeID: 3, recipeTitle: "Test3", cookedAt: Date(), confidence: 4),
        ]
        let result = ConfidenceChallengeBias.bias(for: entries)
        #expect(result == .same)
    }
}
