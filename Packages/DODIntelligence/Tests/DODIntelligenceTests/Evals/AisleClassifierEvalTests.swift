import DODIntelligence
import XCTest

@Suite("AisleClassifierEval")
struct AisleClassifierEvalTests {

    @Test func corpusPassesAllInvariants() async {
        let report = await runEval(AisleClassifierEval.corpus) { AisleClassifierEval.grade($0) }
        #expect(report.meets(threshold: 1.0), Comment(rawValue: report.failureSummary))
    }

    @Test func gradeFlagsWrongExpectation() {
        let bad = AisleExpectation(line: "yellow onion", expected: .dairy)
        #expect(!AisleClassifierEval.grade(bad).isEmpty)
    }
}
