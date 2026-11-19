import DODDomain
import Foundation
import Testing

@testable import DODSupport

@Suite("SplitCookStageClassifier") struct SplitCookStageClassifierTests {
    @Test func explicitStageWins() {
        let step = RecipeInstruction(step: 1, text: "Light the coals", stage: .kitchenPrep)
        #expect(SplitCookStageClassifier.stage(for: step) == .kitchenPrep)
    }

    @Test func chopStepIsKitchenPrep() {
        let step = RecipeInstruction(step: 1, text: "Dice the onion.")
        #expect(SplitCookStageClassifier.stage(for: step) == .kitchenPrep)
    }

    @Test func coalsStepIsCampfire() {
        let step = RecipeInstruction(step: 1, text: "Place coals on the lid.")
        #expect(SplitCookStageClassifier.stage(for: step) == .campfireFinish)
    }

    @Test func tieGoesToCamp() {
        let step = RecipeInstruction(step: 1, text: "Layer noodles then bake with the lid on")
        #expect(SplitCookStageClassifier.stage(for: step) == .campfireFinish)
    }

    @Test func unknownDefaultsToCamp() {
        let step = RecipeInstruction(step: 1, text: "Enjoy the evening.")
        #expect(SplitCookStageClassifier.stage(for: step) == .campfireFinish)
    }

    @Test func partitionSplitsInOrder() {
        let firstStep = RecipeInstruction(step: 1, text: "Chop the peppers.")
        let secondStep = RecipeInstruction(step: 2, text: "Place coals under the oven.")
        let thirdStep = RecipeInstruction(step: 3, text: "Mince the garlic.")
        let result = SplitCookStageClassifier.partition([firstStep, secondStep, thirdStep])
        #expect(result.home.map(\.step) == [1, 3])
        #expect(result.camp.map(\.step) == [2])
    }
}
