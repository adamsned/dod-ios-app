import Testing

@testable import DODFeatureRecipeDetail

@Suite("Training wheels (DUT-986)")
struct TrainingWheelsTests {

    @Test("heatStepIsHeatSetup")
    func heatStepIsHeatSetup() {
        #expect(TrainingWheels.kind(forStepText: "Arrange the coals in a ring.") == .heatSetup)
    }

    @Test("donenessStepIsDoneness")
    func donenessStepIsDoneness() {
        #expect(TrainingWheels.kind(forStepText: "Bake until golden brown.") == .doneness)
    }

    @Test("plainStepIsNil")
    func plainStepIsNil() {
        #expect(TrainingWheels.kind(forStepText: "Stir in the flour.") == nil)
    }

    @Test("noteIsNilWhenNotFirstCook")
    func noteIsNilWhenNotFirstCook() {
        #expect(TrainingWheels.note(forStepText: "Arrange the coals.", isFirstCookEver: false) == nil)
    }

    @Test("noteIsPresentWhenFirstCook")
    func noteIsPresentWhenFirstCook() {
        #expect(TrainingWheels.note(forStepText: "Arrange the coals.", isFirstCookEver: true)?.kind == .heatSetup)
    }
}
