import Testing

@testable import DODFeatureFeed

@Suite("CookCelebration (DUT-983)") struct CookCelebrationTests {
    @Test func firstCookEverHasAStableDistinctID() {
        #expect(CookCelebration.firstCookEver.id == "first-cook-ever")
        #expect(CookCelebration.firstCookEver.id != CookCelebration.graduatedFirstCookout.id)
    }
}
