import DODIntelligence
import Testing

@Suite("AisleClassifierEval")
struct AisleClassifierEvalTests {

    @Test func corpusPassesAllInvariants() async {
        let report = await runEval(AisleClassifierEval.corpus) { AisleClassifierEval.grade($0) }
        #expect(report.meets(threshold: 1.0))
    }

    @Test func gradeFlagsWrongExpectation() {
        let bad = AisleExpectation(line: "yellow onion", expected: .dairy)
        #expect(!AisleClassifierEval.grade(bad).isEmpty)
    }
}
