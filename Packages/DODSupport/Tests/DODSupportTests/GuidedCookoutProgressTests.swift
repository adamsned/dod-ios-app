import Testing

@testable import DODSupport

@Suite("GuidedCookout progress (DUT-964)")
struct GuidedCookoutProgressTests {

    @Test func emptyJournalIsZeroOfThree() {
        let progress = GuidedCookout.pathProgress(cookedRecipeIDs: [])
        #expect(progress.cookedRungs == 0)
        #expect(progress.fraction == 0)
        #expect(progress.nextRung?.recipeID == GuidedCookout.firstCookout.recipeID)
        #expect(progress.isGraduate == false)
    }

    @Test func outOfOrderCookCountsOnce() {
        let progress = GuidedCookout.pathProgress(cookedRecipeIDs: [GuidedCookout.italianChicken.recipeID])
        #expect(progress.cookedRungs == 1)
        #expect(progress.nextRung?.recipeID == GuidedCookout.firstCookout.recipeID)
    }

    @Test func offPathIDsAreIgnored() {
        let progress = GuidedCookout.pathProgress(cookedRecipeIDs: [999_999])
        #expect(progress.cookedRungs == 0)
    }

    @Test func allRungsCookedIsGraduate() {
        let allRungIDs = GuidedCookout.path.map(\.recipeID)
        let progress = GuidedCookout.pathProgress(cookedRecipeIDs: Set(allRungIDs))
        #expect(progress.isGraduate == true)
        #expect(progress.fraction == 1)
    }
}
