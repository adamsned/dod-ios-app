import Foundation
import Testing

@testable import DODSupport

@Suite("ProbeReading (DUT-135)")
struct ProbeReadingTests {

    @Test func testNearThenTargetFireOnceEach() {
        var evaluator = ProbeAlertEvaluator(targetF: 165)

        // A reading of 150 gives nil
        let reading1 = ProbeReading(internalF: 150)
        #expect(evaluator.evaluate(reading1) == nil)

        // 156 gives `.nearTarget`
        let reading2 = ProbeReading(internalF: 156)
        #expect(evaluator.evaluate(reading2) == .nearTarget)

        // 157 gives nil
        let reading3 = ProbeReading(internalF: 157)
        #expect(evaluator.evaluate(reading3) == nil)

        // 165 gives `.targetReached`
        let reading4 = ProbeReading(internalF: 165)
        #expect(evaluator.evaluate(reading4) == .targetReached)

        // 170 gives nil
        let reading5 = ProbeReading(internalF: 170)
        #expect(evaluator.evaluate(reading5) == nil)
    }

    @Test func testJumpStraightToTargetSkipsNear() {
        var evaluator = ProbeAlertEvaluator(targetF: 165)

        // The first reading is 170, which gives `.targetReached`
        let reading1 = ProbeReading(internalF: 170)
        #expect(evaluator.evaluate(reading1) == .targetReached)

        // A later reading of 171 gives nil
        let reading2 = ProbeReading(internalF: 171)
        #expect(evaluator.evaluate(reading2) == nil)
    }
}
