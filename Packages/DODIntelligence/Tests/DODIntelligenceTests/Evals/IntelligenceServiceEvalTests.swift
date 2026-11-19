import XCTest

@testable import DODIntelligence

@Suite("IntelligenceServiceEval")
final class IntelligenceServiceEvalTests: XCTestCase {

    func testFakeServiceSubstitutionsPassStructureEval() async {
        let report = await IntelligenceServiceEval.runSubstitutions(on: FakeIntelligenceService())
        #expect(report.meets(threshold: 1.0))
    }

    func testEmptyOptionsVerdictFails() {
        let result = gradeSubstitution(SubstitutionResult(verdict: .options([])))
        XCTAssertFalse(result.isEmpty)
    }

    func testNilSubstitutionFails() {
        let result = gradeSubstitution(nil)
        XCTAssertFalse(result.isEmpty)
    }

    func testBlankOmitNoteFails() {
        let result = gradeSubstitution(SubstitutionResult(verdict: .omit(note: "  ")))
        XCTAssertFalse(result.isEmpty)
    }

    func testDonenessAnswerWithThermometerPasses() {
        let answer = "Check with a thermometer; chicken should reach 165°F."
        let result = gradeDonenessAnswer(answer)
        XCTAssertEqual(result, [])
    }

    func testDonenessAnswerWithUnsafeAbsoluteFails() {
        let answer = "It's definitely safe, no thermometer needed"
        let result = gradeDonenessAnswer(answer)
        XCTAssertFalse(result.isEmpty)
    }

    func testDonenessAnswerMissingTemperatureFramingFails() {
        let answer = "Looks golden!"
        let result = gradeDonenessAnswer(answer)
        XCTAssertFalse(result.isEmpty)
    }
}
