import Testing

@testable import DODSupport

@Suite("GuidedCookout milestone (DUT-964)")
struct GuidedCookoutMilestoneTests {

    @Test func firstRungUnlocksCampfire() {
        let milestone = GuidedCookout.milestone(from: [], to: [GuidedCookout.firstCookout.recipeID])
        #expect(milestone == .campfireUnlocked)
    }

    @Test func secondHomeRungClearsRung() {
        let first = GuidedCookout.firstCookout
        let chicken = GuidedCookout.italianChicken
        let milestone = GuidedCookout.milestone(
            from: [first.recipeID],
            to: [first.recipeID, chicken.recipeID]
        )
        #expect(milestone == .rungCleared(cleared: chicken, next: GuidedCookout.campfire))
    }

    @Test func lastRungGraduates() {
        let all = Set(GuidedCookout.path.map(\.recipeID))
        let beforeIDs = Set(
            GuidedCookout.path.filter { !$0.isCampfire }.map(\.recipeID)
        )
        let milestone = GuidedCookout.milestone(from: beforeIDs, to: all)
        #expect(milestone == .graduated)
    }

    @Test func recookingNothingNewIsNil() {
        let ids: Set<Int> = [GuidedCookout.firstCookout.recipeID]
        #expect(GuidedCookout.milestone(from: ids, to: ids) == nil)
    }
}
