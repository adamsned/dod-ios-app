import DODSupport
import Foundation
import Testing

@testable import DODIntelligence

@Suite("NextRungCoach")
struct NextRungCoachTests {
    private let candidates = [
        NextRungCandidate(recipeID: 3, title: "Soup", difficulty: 1),
        NextRungCandidate(recipeID: 1, title: "Roast", difficulty: 3),
        NextRungCandidate(recipeID: 2, title: "Pasta", difficulty: 2),
    ]

    private func signals(totalCooks: Int) -> NextRungSignals {
        NextRungSignals(
            totalCooks: totalCooks,
            daysSinceLastCook: 2,
            lastRating: 5,
            weeklyStreak: 1,
            cooksToNextRank: nil,
            cookedRecipeIDs: [],
            lastCookedRecipeID: nil
        )
    }

    @Test func coldStartIsFlaggedWithNonEmptyWhy() async {
        let result = await DeterministicNextRungCoach().recommend(
            candidates: candidates,
            signals: signals(totalCooks: 0),
            lastCookedDifficulty: nil,
            easier: false
        )
        #expect(result.first?.isColdStart == true)
        #expect(result.first?.why.isEmpty == false)
    }

    @Test func emptyCandidatesReturnEmpty() async {
        let result = await DeterministicNextRungCoach().recommend(
            candidates: [],
            signals: signals(totalCooks: 10),
            lastCookedDifficulty: 2,
            easier: false
        )
        #expect(result.isEmpty)
    }

    @Test func everyRecommendationComesFromInput() async {
        let result = await DeterministicNextRungCoach().recommend(
            candidates: candidates,
            signals: signals(totalCooks: 10),
            lastCookedDifficulty: 2,
            easier: false
        )
        let inputIDs = Set(candidates.map(\.recipeID))
        #expect(result.count == candidates.count)
        #expect(result.allSatisfy { inputIDs.contains($0.candidate.recipeID) })
    }

    @Test func gapWhyLineMentionsDays() {
        let line = DeterministicNextRungCoach.whyLine(.easedAfterGap(days: 30))
        #expect(line.contains("30"))
    }
}
