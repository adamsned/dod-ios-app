import Foundation
import Testing

@testable import DODSupport

@Suite("NextRungScorer") struct NextRungScorerTests {
    private let candidates = [
        NextRungCandidate(recipeID: 1, title: "One", difficulty: 1),
        NextRungCandidate(recipeID: 2, title: "Two", difficulty: 2),
        NextRungCandidate(recipeID: 3, title: "Three", difficulty: 3),
    ]

    private func signals(
        totalCooks: Int = 10,
        days: Int? = 3,
        rating: Int? = 5,
        cooked: Set<Int> = []
    ) -> NextRungSignals {
        NextRungSignals(
            totalCooks: totalCooks,
            daysSinceLastCook: days,
            lastRating: rating,
            weeklyStreak: 0,
            cooksToNextRank: nil,
            cookedRecipeIDs: cooked,
            lastCookedRecipeID: nil
        )
    }

    @Test func coldStartPicksEasiest() {
        let ranked = NextRungScorer.rank(
            candidates,
            signals: signals(totalCooks: 1),
            lastCookedDifficulty: nil
        )
        #expect(ranked.first?.candidate.difficulty == 1)
        #expect(ranked.first?.reason == .coldStart)
    }

    @Test func warmCookStepsUp() {
        let ranked = NextRungScorer.rank(candidates, signals: signals(), lastCookedDifficulty: 2)
        #expect(ranked.first?.candidate.difficulty == 3)
        #expect(ranked.first?.reason == .steppingUp)
    }

    @Test func longGapDoesNotJump() {
        let ranked = NextRungScorer.rank(candidates, signals: signals(days: 30), lastCookedDifficulty: 2)
        #expect(ranked.first?.candidate.difficulty == 2)
        #expect(ranked.first?.reason == .easedAfterGap(days: 30))
    }

    @Test func lowRatingDoesNotJump() {
        let ranked = NextRungScorer.rank(candidates, signals: signals(rating: 1), lastCookedDifficulty: 2)
        #expect(ranked.first?.candidate.difficulty == 2)
        #expect(ranked.first?.reason == .easedAfterLowRating(1))
    }

    @Test func easierDropsOneNotch() {
        let ranked = NextRungScorer.rank(
            candidates,
            signals: signals(),
            lastCookedDifficulty: 2,
            easier: true
        )
        #expect(ranked.first?.candidate.difficulty == 2)
    }
}
