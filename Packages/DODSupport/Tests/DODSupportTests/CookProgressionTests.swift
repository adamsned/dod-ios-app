import Testing

@testable import DODSupport

/// The transformation rank ladder: total cooks → an identity that climbs toward
/// "Dutch Oven Daddy", with the next rung + progress so the Cooking Journal can
/// show growth, not just a number.
@Suite("CookProgression rank ladder") struct CookProgressionTests {

    @Test func currentRankClimbsWithCooks() {
        #expect(CookProgression.currentRank(totalCooks: 0) == nil)  // pre-first-cook
        #expect(CookProgression.currentRank(totalCooks: 1)?.title == "Fire Starter")
        #expect(CookProgression.currentRank(totalCooks: 4)?.title == "Coal Tender")  // 3..4
        #expect(CookProgression.currentRank(totalCooks: 5)?.title == "Lid Lifter")
        #expect(CookProgression.currentRank(totalCooks: 50)?.title == "Dutch Oven Daddy")
        #expect(CookProgression.currentRank(totalCooks: 999)?.title == "Dutch Oven Daddy")  // caps
    }

    @Test func nextRankPullsForwardThenEndsAtTheTop() {
        #expect(CookProgression.nextRank(totalCooks: 0)?.title == "Fire Starter")
        #expect(CookProgression.nextRank(totalCooks: 1)?.title == "Coal Tender")
        #expect(CookProgression.nextRank(totalCooks: 49)?.title == "Dutch Oven Daddy")
        #expect(CookProgression.nextRank(totalCooks: 50) == nil)  // top rung reached
    }

    @Test func cooksToNextRankCountsDown() {
        #expect(CookProgression.cooksToNextRank(totalCooks: 0) == 1)
        #expect(CookProgression.cooksToNextRank(totalCooks: 1) == 2)  // 3 - 1
        #expect(CookProgression.cooksToNextRank(totalCooks: 4) == 1)  // 5 - 4
        #expect(CookProgression.cooksToNextRank(totalCooks: 50) == nil)
    }

    @Test func progressFillsBetweenRungs() {
        // floor 1 (First Cook), next 3 (Coal Tender): span 2.
        #expect(CookProgression.progressToNextRank(totalCooks: 1) == 0.0)
        #expect(CookProgression.progressToNextRank(totalCooks: 2) == 0.5)
        // at/after the top rung → full.
        #expect(CookProgression.progressToNextRank(totalCooks: 50) == 1.0)
        #expect(CookProgression.progressToNextRank(totalCooks: 100) == 1.0)
    }

    @Test func theTopRungIsTheBrand() {
        #expect(CookProgression.ranks.last?.title == "Dutch Oven Daddy")
        #expect(CookProgression.ranks.map(\.threshold) == CookProgression.ranks.map(\.threshold).sorted())
    }
}
