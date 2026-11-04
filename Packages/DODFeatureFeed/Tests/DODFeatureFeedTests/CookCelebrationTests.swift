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
}
