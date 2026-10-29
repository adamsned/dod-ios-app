import Testing

@testable import DODIntelligence

@Suite("EvalTypes runEval")
struct EvalRunnerTests {
    @Test func runEvalCollectsOneOutcomePerCase() async {
        let report = await runEval([
            EvalCase(name: "a", input: 1),
            EvalCase(name: "b", input: 2),
        ]) { $0 == 1 ? [] : ["bad"] }
        #expect(
            report.outcomes == [
                EvalOutcome(caseName: "a", failures: []),
                EvalOutcome(caseName: "b", failures: ["bad"]),
            ]
        )
    }
}
