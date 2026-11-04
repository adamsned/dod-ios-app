import Testing

@testable import DODSupport

/// L1 coverage for the DUT-173 Cook Mode auto-advance preference.
@Suite("CookModeAutoAdvance (DUT-173)")
struct CookModeAutoAdvanceTests {

    @Test func enabledCurrentStepOneOfFourReturnsTrue() {
        #expect(
            CookModeAutoAdvance.shouldAdvance(enabled: true, completedStep: 1, currentStep: 1, stepCount: 4) == true
        )
    }

    @Test func disabledReturnsFalse() {
        #expect(
            CookModeAutoAdvance.shouldAdvance(enabled: false, completedStep: 1, currentStep: 1, stepCount: 4) == false
        )
    }

    @Test func lastStepReturnsFalse() {
        #expect(
            CookModeAutoAdvance.shouldAdvance(enabled: true, completedStep: 3, currentStep: 3, stepCount: 4) == false
        )
    }

    @Test func completedStepNotCurrentStepReturnsFalse() {
        #expect(
            CookModeAutoAdvance.shouldAdvance(enabled: true, completedStep: 2, currentStep: 1, stepCount: 4) == false
        )
    }

    @Test func defaultEnabledIsFalse() {
        #expect(CookModeAutoAdvance.defaultEnabled == false)
    }
}
