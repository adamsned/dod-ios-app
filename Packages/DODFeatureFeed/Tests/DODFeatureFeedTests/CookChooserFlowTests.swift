import DODSupport
import Testing

@testable import DODFeatureFeed

/// L1 coverage for the DUT-194 chooser's pure selection + ordering logic (the
/// parts that decide what a beginner vs a returning cook sees).
@Suite("CookChooserFlow (DUT-194)")
struct CookChooserFlowTests {

    // DUT-235 — the chooser is now ALWAYS shown (no auto-jump into the first
    // rung); the prior `initialSelection` bypass + its test were removed so a
    // beginner sees the choice of first cook.

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
