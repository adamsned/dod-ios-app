import Testing

@testable import DODFeatureRecipeDetail

/// L1 coverage for the DUT-596 Cook Mode progress model: the completion
/// fraction, the star-filled (finished) decision, and the caption copy that
/// replaced the old page-dot indicator.
@Suite("CookModeProgress (DUT-596)")
struct CookModeProgressTests {

    @Test func fractionAdvancesWithStep() {
        let first = CookModeProgress(currentStepIndex: 0, stepCount: 4, isFinished: false)
        let third = CookModeProgress(currentStepIndex: 2, stepCount: 4, isFinished: false)
        #expect(first.fraction == 0.25)
        #expect(third.fraction == 0.75)
    }

    @Test func lastStepIsNotYetFull() {
        // On the final step (but not finished) the bar shows full because
        // (index + 1) / count == 1, but the star stays an outline until finished.
        let lastStep = CookModeProgress(currentStepIndex: 3, stepCount: 4, isFinished: false)
        #expect(lastStep.fraction == 1.0)
        #expect(lastStep.isFinished == false)
    }

    @Test func finishedIsFullAndFillsStar() {
        let done = CookModeProgress(currentStepIndex: 3, stepCount: 4, isFinished: true)
        #expect(done.fraction == 1.0)
        #expect(done.isFinished == true)
        #expect(done.counterLabel == "Done")
        #expect(done.accessibilityLabel == "Cooking complete")
    }

    @Test func captionCountsFromOne() {
        let step = CookModeProgress(currentStepIndex: 1, stepCount: 5, isFinished: false)
        #expect(step.counterLabel == "Step 2 of 5")
        #expect(step.accessibilityLabel == "Step 2 of 5")
    }

    @Test func clampsIntoRangeAndAvoidsDivideByZero() {
        let empty = CookModeProgress(currentStepIndex: 0, stepCount: 0, isFinished: false)
        #expect(empty.stepCount == 1)
        #expect(empty.fraction == 1.0)

        let overshoot = CookModeProgress(currentStepIndex: 99, stepCount: 3, isFinished: false)
        #expect(overshoot.activeIndex == 2)
        #expect(overshoot.fraction == 1.0)
    }

    @Test func manyStepsStayInBounds() {
        // The bar (not dots) scales to long recipes; midpoint reads ~0.5.
        let mid = CookModeProgress(currentStepIndex: 9, stepCount: 20, isFinished: false)
        #expect(mid.fraction == 0.5)
        #expect(mid.counterLabel == "Step 10 of 20")
    }
}
