import DODSupport
import Testing

@testable import DODFeatureFeed

@Suite("CookCelebration (DUT-983)") struct CookCelebrationTests {
    @Test func firstCookEverHasAStableDistinctID() {
        #expect(CookCelebration.firstCookEver.id == "first-cook-ever")
        #expect(CookCelebration.firstCookEver.id != CookCelebration.graduatedFirstCookout.id)
    }

    @Test func ownedItIDIsStablePerRecipeAndDistinct() {
        #expect(CookCelebration.ownedIt(title: "Chili").id == "owned-Chili")
        #expect(CookCelebration.ownedIt(title: "Chili").id != CookCelebration.ownedIt(title: "Bread").id)
        #expect(CookCelebration.ownedIt(title: "Chili").id != CookCelebration.firstCookEver.id)
    }

    @Test func rungMilestoneIdsAreDistinct() {
        #expect(CookCelebration.rungMilestone(.campfireUnlocked).id != CookCelebration.rungMilestone(.graduated).id)
        #expect(CookCelebration.rungMilestone(.campfireUnlocked).id != CookCelebration.firstCookEver.id)
        #expect(CookCelebration.rungMilestone(.graduated).id != CookCelebration.firstCookEver.id)
    }

    @Test func runClearedIdUsesRecipeID() {
        let cleared = GuidedCookout.italianChicken
        let next = GuidedCookout.campfire
        #expect(
            CookCelebration.rungMilestone(.rungCleared(cleared: cleared, next: next)).id == "rung-\(cleared.recipeID)"
        )
    }
}
