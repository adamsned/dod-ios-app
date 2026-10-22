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
}
