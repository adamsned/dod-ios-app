import Testing

@testable import DODSupport

/// L1 coverage for the "Your First Cookout" content spine (US-53 / DUT-183).
/// Pure content validation — pins that the curated coached path is complete and
/// well-formed so the UI flow can trust it.
@Suite("GuidedCookout (DUT-183)")
struct GuidedCookoutTests {

    private var cookout: GuidedCookout { GuidedCookout.firstCookout }

    @Test func curatedFirstCookoutIsTheGatewayDish() {
        #expect(cookout.recipeSlug == "dutch-oven-lasagna")
        #expect(cookout.dishTitle == "Dutch Oven Lasagna")
        #expect(cookout.whyThisDish.isEmpty == false)
        #expect(cookout.celebrationMessage.isEmpty == false)
        #expect(cookout.nextStepPrompt.isEmpty == false)
        // Cooking params drive the live coal count at the fire stage (DUT-128).
        #expect(cookout.ovenTempF == 375)
        #expect(cookout.ovenDiameterInches == 12)
    }

    @Test func coversAllFourStagesInOrder() {
        // The first cookout must walk gather → fire → cook → celebrate.
        let stageOrder = cookout.steps.map(\.stage)
        for stage in GuidedCookout.Stage.allCases {
            #expect(cookout.steps(in: stage).isEmpty == false, "missing stage \(stage)")
        }
        // The stages appear in their canonical order (no celebrate-before-fire).
        let canonical = GuidedCookout.Stage.allCases
        let firstIndexByStage = canonical.compactMap { stage in
            stageOrder.firstIndex(of: stage)
        }
        #expect(firstIndexByStage == firstIndexByStage.sorted())
    }

    @Test func everyStepIsWellFormedWithUniqueIDs() {
        for step in cookout.steps {
            #expect(step.id.isEmpty == false)
            #expect(step.title.isEmpty == false)
            #expect(step.coaching.isEmpty == false)
        }
        let ids = cookout.steps.map(\.id)
        #expect(Set(ids).count == ids.count, "step ids must be unique")
    }

    @Test func stepsInStageFiltersCorrectly() {
        let fireSteps = cookout.steps(in: .fire)
        #expect(fireSteps.allSatisfy { $0.stage == .fire })
        #expect(fireSteps.isEmpty == false)
    }
}
