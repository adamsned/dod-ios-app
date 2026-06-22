import DODSupport
import Testing

@testable import DODFeatureFeed

/// L1 coverage for the DUT-194 chooser's pure selection + ordering logic (the
/// parts that decide what a beginner vs a returning cook sees).
@Suite("CookChooserFlow (DUT-194)")
struct CookChooserFlowTests {

    @Test func firstRungBeginnerJumpsStraightIntoCoaching() {
        // A true beginner (recommended == the first rung) skips the chooser.
        #expect(
            CookChooserFlow.initialSelection(recommended: GuidedCookout.firstCookout)?.recipeID
                == GuidedCookout.firstCookout.recipeID
        )
        // A returning cook (recommended == a later rung) sees the chooser.
        #expect(CookChooserFlow.initialSelection(recommended: GuidedCookout.italianChicken) == nil)
        // No recommendation -> the chooser.
        #expect(CookChooserFlow.initialSelection(recommended: nil) == nil)
    }

    @Test func recommendedRungIsHoistedAndDeduped() {
        let chicken = GuidedCookout.italianChicken
        let ordered = CookChooserFlow.orderedRungs(recommended: chicken)
        #expect(ordered.first?.recipeID == chicken.recipeID)  // hoisted to the top
        #expect(ordered.filter { $0.recipeID == chicken.recipeID }.count == 1)  // not duplicated
        #expect(ordered.count == GuidedCookout.path.count)  // every rung present, once
    }

    @Test func nilRecommendedKeepsPathOrder() {
        let ordered = CookChooserFlow.orderedRungs(recommended: nil)
        #expect(ordered.map(\.recipeID) == GuidedCookout.path.map(\.recipeID))
    }
}
