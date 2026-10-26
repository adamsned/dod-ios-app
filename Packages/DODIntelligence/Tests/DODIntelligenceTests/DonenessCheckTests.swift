import Testing
import XCTest

@testable import DODIntelligence

@Suite
struct DonenessCheckTests {

    @Test
    func confidence09KeepsLooksDone() {
        let result = DonenessCheckResult(
            verdict: .looksDone,
            confidence: 0.9,
            reassurance: "The crust looks golden brown."
        )

        #expect(result.verdict == .looksDone)
        #expect(result.confidence == 0.9)
        #expect(result.reassurance == "The crust looks golden brown.")
    }

    @Test
    func confidence03ForcesUnsure() {
        let result = DonenessCheckResult(
            verdict: .looksDone,
            confidence: 0.3,
            reassurance: "The crust looks golden brown."
        )

        #expect(result.verdict == .unsure)
        #expect(result.confidence == 0.3)
        #expect(result.reassurance == "The crust looks golden brown.")
    }

    @Test
    func confidence5ClampsTo1() {
        let result = DonenessCheckResult(
            verdict: .looksDone,
            confidence: 5.0,
            reassurance: "The crust looks golden brown."
        )

        #expect(result.verdict == .looksDone)
        #expect(result.confidence == 1.0)
        #expect(result.reassurance == "The crust looks golden brown.")
    }

    @Test
    func reassuranceWithSafetyClaimIsReplaced() {
        let result = DonenessCheckResult(
            verdict: .looksDone,
            confidence: 0.9,
            reassurance: "It's 165 degrees inside."
        )

        #expect(result.verdict == .looksDone)
        #expect(result.confidence == 0.9)
        #expect(result.reassurance == DonenessCheckResult.unsureNote)
    }
}
