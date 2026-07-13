import Foundation
import Testing

@testable import DODFeatureProfile

/// L1 coverage for ``ProfileStats`` initializer and the ``rankLadderCooks``
/// defaulting logic (DUT-685). The struct holds profile stats (total cooks,
/// rank ladder cooks, weekly streak, saved recipes, reviews written). The key
/// logic is that `rankLadderCooks` defaults to `totalCooks` when nil, ensuring
/// existing callers that don't yet distinguish path-only cooks keep their prior
/// behavior; the composition root passes the real path-only count for DUT-685.
///
/// Spec trace: DUT-685.
@Suite("ProfileStats init (DUT-685)")
struct ProfileStatsInitTests {

    @Test func initWithExplicitRankLadderCooksPreservesValue() {
        let stats = ProfileStats(
            totalCooks: 10,
            rankLadderCooks: 8,
            weeklyStreak: 2,
            savedRecipes: 5,
            reviewsWritten: 3
        )

        #expect(stats.totalCooks == 10)
        #expect(stats.rankLadderCooks == 8)
        #expect(stats.weeklyStreak == 2)
        #expect(stats.savedRecipes == 5)
        #expect(stats.reviewsWritten == 3)
    }

    @Test func initWithNilRankLadderCooksDefaultsToTotalCooks() {
        let stats = ProfileStats(
            totalCooks: 15,
            rankLadderCooks: nil,
            weeklyStreak: 3,
            savedRecipes: 7,
            reviewsWritten: 4
        )

        #expect(stats.totalCooks == 15)
        #expect(stats.rankLadderCooks == 15)  // defaults to totalCooks
        #expect(stats.weeklyStreak == 3)
        #expect(stats.savedRecipes == 7)
        #expect(stats.reviewsWritten == 4)
    }

    @Test func initWithoutProvidingRankLadderCooksDefaultsToTotalCooks() {
        let stats = ProfileStats(
            totalCooks: 20,
            weeklyStreak: 4,
            savedRecipes: 9,
            reviewsWritten: 5
        )

        #expect(stats.totalCooks == 20)
        #expect(stats.rankLadderCooks == 20)  // defaults to totalCooks
        #expect(stats.weeklyStreak == 4)
        #expect(stats.savedRecipes == 9)
        #expect(stats.reviewsWritten == 5)
    }

    @Test func initWithZeroTotalCooksDefaultsRankLadderToZero() {
        let stats = ProfileStats(
            totalCooks: 0,
            weeklyStreak: 0,
            savedRecipes: 0,
            reviewsWritten: nil
        )

        #expect(stats.totalCooks == 0)
        #expect(stats.rankLadderCooks == 0)
        #expect(stats.weeklyStreak == 0)
        #expect(stats.savedRecipes == 0)
        #expect(stats.reviewsWritten == nil)
    }

    @Test func initWithNilReviewsWrittenPreservesNil() {
        let stats = ProfileStats(
            totalCooks: 5,
            weeklyStreak: 1,
            savedRecipes: 2,
            reviewsWritten: nil
        )

        #expect(stats.reviewsWritten == nil)
    }

    @Test func emptyConstantHasAllZeroValues() {
        let empty = ProfileStats.empty

        #expect(empty.totalCooks == 0)
        #expect(empty.rankLadderCooks == 0)
        #expect(empty.weeklyStreak == 0)
        #expect(empty.savedRecipes == 0)
        #expect(empty.reviewsWritten == nil)
    }

    @Test func profileStatsIsEquatable() {
        let stats1 = ProfileStats(
            totalCooks: 10,
            rankLadderCooks: 8,
            weeklyStreak: 2,
            savedRecipes: 5,
            reviewsWritten: 3
        )
        let stats2 = ProfileStats(
            totalCooks: 10,
            rankLadderCooks: 8,
            weeklyStreak: 2,
            savedRecipes: 5,
            reviewsWritten: 3
        )
        let stats3 = ProfileStats(
            totalCooks: 11,
            rankLadderCooks: 8,
            weeklyStreak: 2,
            savedRecipes: 5,
            reviewsWritten: 3
        )

        #expect(stats1 == stats2)
        #expect(stats1 != stats3)
    }
}
