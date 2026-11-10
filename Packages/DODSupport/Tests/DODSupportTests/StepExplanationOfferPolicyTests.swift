import Testing

@testable import DODSupport

@Suite
struct StepExplanationOfferPolicyTests {
    @Test
    func offeredForNewUser() {
        #expect(StepExplanationOfferPolicy.shouldOffer(explainCount: 0, hasLevelledUp: false) == true)
    }

    @Test
    func hiddenAfterLevelUp() {
        #expect(StepExplanationOfferPolicy.shouldOffer(explainCount: 0, hasLevelledUp: true) == false)
    }

    @Test
    func hiddenAtThreshold() {
        #expect(
            StepExplanationOfferPolicy.shouldOffer(
                explainCount: StepExplanationOfferPolicy.dismissThreshold,
                hasLevelledUp: false
            ) == false
        )
    }

    @Test
    func offeredJustBelowThreshold() {
        #expect(
            StepExplanationOfferPolicy.shouldOffer(
                explainCount: StepExplanationOfferPolicy.dismissThreshold - 1,
                hasLevelledUp: false
            ) == true
        )
    }
}
