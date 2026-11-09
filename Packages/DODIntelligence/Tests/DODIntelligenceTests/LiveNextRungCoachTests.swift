import DODSupport
import Foundation
import Testing

@testable import DODIntelligence

@Suite("LiveNextRungCoach")
struct LiveNextRungCoachTests {
    private let candidates = [
        NextRungCandidate(recipeID: 3, title: "Soup", difficulty: 1),
        NextRungCandidate(recipeID: 1, title: "Roast", difficulty: 3),
        NextRungCandidate(recipeID: 2, title: "Pasta", difficulty: 2),
    ]

    private func ranked() -> [NextRungRecommendation] {
        candidates.map {
            NextRungRecommendation(candidate: $0, why: "deterministic \($0.recipeID)", isColdStart: false)
        }
    }

    private var coldSignals: NextRungSignals {
        NextRungSignals(
            totalCooks: 0,
            daysSinceLastCook: nil,
            lastRating: nil,
            weeklyStreak: 0,
            cooksToNextRank: nil,
            cookedRecipeIDs: [],
            lastCookedRecipeID: nil
        )
    }

    @Test func resolveRejectsIDNotInRankedList() {
        #expect(LiveNextRungCoach.resolve(pickID: 99, why: "x", in: ranked()) == nil)
    }

    @Test func resolveKeepsModelWhyForValidID() {
        let result = LiveNextRungCoach.resolve(pickID: 1, why: "  Great next step.  ", in: ranked())
        #expect(result?.candidate.recipeID == 1)
        #expect(result?.why == "Great next step.")
    }

    @Test func resolveKeepsDeterministicWhyWhenBlank() {
        let result = LiveNextRungCoach.resolve(pickID: 2, why: "   ", in: ranked())
        #expect(result?.candidate.recipeID == 2)
        #expect(result?.why == "deterministic 2")
    }

    @Test func coldStartMatchesDeterministicCoach() async {
        let live = await LiveNextRungCoach().recommend(
            candidates: candidates,
            signals: coldSignals,
            lastCookedDifficulty: nil,
            easier: false
        )
        let expected = await DeterministicNextRungCoach().recommend(
            candidates: candidates,
            signals: coldSignals,
            lastCookedDifficulty: nil,
            easier: false
        )
        #expect(live == expected)
    }
}
