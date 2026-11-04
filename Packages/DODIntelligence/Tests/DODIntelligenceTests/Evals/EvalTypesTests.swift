import Testing

@testable import DODIntelligence

@Suite("EvalTypes")
struct EvalTypesTests {
    @Test func passRateIsFractionOfPassingOutcomes() {
        let report = EvalReport(outcomes: [
            EvalOutcome(caseName: "a", failures: []),
            EvalOutcome(caseName: "b", failures: []),
            EvalOutcome(caseName: "c", failures: ["x"]),
        ])
        #expect(abs(report.passRate - 2.0 / 3.0) < 0.001)
        #expect(report.meets(threshold: 0.6))
        #expect(!report.meets(threshold: 0.9))
    }

    @Test func emptyReportHasZeroPassRate() {
        #expect(EvalReport(outcomes: []).passRate == 0)
    }

    @Test func failureSummaryListsOnlyFailures() {
        let report = EvalReport(outcomes: [
            EvalOutcome(caseName: "good", failures: []),
            EvalOutcome(caseName: "bad", failures: ["x"]),
        ])
        #expect(report.failureSummary.contains("bad"))
        #expect(!report.failureSummary.contains("good"))
    }
}
