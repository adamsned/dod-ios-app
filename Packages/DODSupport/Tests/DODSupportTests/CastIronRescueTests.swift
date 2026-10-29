import Testing

@testable import DODSupport

@Suite("CastIronRescue (DUT-970)") struct CastIronRescueTests {
    @Test func everyProblemHasReassuranceAndSteps() {
        for problem in CastIronRescue.Problem.allCases {
            let rescue = CastIronRescue.rescue(for: problem)
            #expect(!rescue.reassurance.isEmpty)
            #expect((2...4).contains(rescue.steps.count))
            #expect(!problem.title.isEmpty)
        }
    }
    @Test func allMatchesCaseCount() {
        #expect(CastIronRescue.all.count == CastIronRescue.Problem.allCases.count)
    }
    @Test func heatTipUsesTemperatureWhenConfident() {
        let profile = RecipeHeatProfile.Derived(ovenTempF: 375, task: .bake)
        #expect(CastIronRescue.heatTip(for: .tooHot, profile: profile)?.contains("375") == true)
        #expect(CastIronRescue.heatTip(for: .underdoneCenter, profile: profile)?.contains("375") == true)
    }
    @Test func heatTipNilWithoutProfileOrForNonHeatProblems() {
        #expect(CastIronRescue.heatTip(for: .tooHot, profile: nil) == nil)
        let profile = RecipeHeatProfile.Derived(ovenTempF: 375, task: .bake)
        #expect(CastIronRescue.heatTip(for: .sticking, profile: profile) == nil)
        #expect(CastIronRescue.heatTip(for: .flareUp, profile: profile) == nil)
    }
}
