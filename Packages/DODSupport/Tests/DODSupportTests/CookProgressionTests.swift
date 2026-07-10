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
        #expect(CookProgression.currentRank(totalCooks: 50)?.title == "Cast Iron Legend")
        #expect(CookProgression.currentRank(totalCooks: 999)?.title == "Cast Iron Legend")  // caps
    }

    @Test func nextRankPullsForwardThenEndsAtTheTop() {
        #expect(CookProgression.nextRank(totalCooks: 0)?.title == "Fire Starter")
        #expect(CookProgression.nextRank(totalCooks: 1)?.title == "Coal Tender")
        #expect(CookProgression.nextRank(totalCooks: 49)?.title == "Cast Iron Legend")
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
        #expect(CookProgression.ranks.last?.title == "Cast Iron Legend")
        #expect(CookProgression.ranks.map(\.threshold) == CookProgression.ranks.map(\.threshold).sorted())
    }

    @Test func rankUpFiresOnlyWhenCrossingAThreshold() {
        #expect(CookProgression.rankUp(from: 0, to: 1)?.title == "Fire Starter")  // first cook
        #expect(CookProgression.rankUp(from: 2, to: 3)?.title == "Coal Tender")  // crosses 3
        #expect(CookProgression.rankUp(from: 1, to: 2) == nil)  // still Fire Starter
        #expect(CookProgression.rankUp(from: 5, to: 5) == nil)  // no new cook
        #expect(CookProgression.rankUp(from: 49, to: 50)?.title == "Cast Iron Legend")
        #expect(CookProgression.rankUp(from: 50, to: 51) == nil)  // already at the top
    }

    // MARK: - Owner rank (Daddy Mode)

    @Test func ownerAlwaysDisplaysTheDutchOvenDaddyRank() {
        // Auto-applied from the very start (0 cooks) and unchanged at any count —
        // the owner's rank is fixed, not earned.
        let atStart = CookProgression.displayRank(totalCooks: 0, isOwner: true)
        #expect(atStart?.title == "The Dutch Oven Daddy")
        #expect(atStart?.emoji == "👑")
        let deepIn = CookProgression.displayRank(totalCooks: 100, isOwner: true)
        #expect(deepIn?.title == "The Dutch Oven Daddy")
        #expect(deepIn == CookProgression.dutchOvenDaddy)
    }

    @Test func nonOwnerDisplaysTheNormalLadderRank() {
        // Non-owner falls through to the earned ladder result at every count.
        #expect(CookProgression.displayRank(totalCooks: 0, isOwner: false) == nil)
        #expect(CookProgression.displayRank(totalCooks: 1, isOwner: false)?.title == "Fire Starter")
        #expect(CookProgression.displayRank(totalCooks: 100, isOwner: false)?.title == "Cast Iron Legend")
    }

    @Test func ownerRankIsNotARungOnTheEarnableLadder() {
        // The owner rank is an override, never inserted into `ranks`, so no cook
        // count can ever produce it via `currentRank` / `rankUp`.
        #expect(!CookProgression.ranks.contains(CookProgression.dutchOvenDaddy))
        #expect(CookProgression.currentRank(totalCooks: 999) != CookProgression.dutchOvenDaddy)
    }
}
