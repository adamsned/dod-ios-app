import XCTest

@testable import DODIntelligence

final class StepExplanationTests: XCTestCase {

    func testGroundedWhenNoNumbers() {
        XCTAssertTrue(StepExplanation.canned.isGrounded(in: "Fold in the egg whites"))
    }

    func testInventedTemperatureIsRejected() {
        let explanation = StepExplanation(
            expandedText: "Bake at 400°F",
            whyItMatters: "High temperature helps set the crust.",
            commonMistake: "Underbaking."
        )
        XCTAssertFalse(explanation.isGrounded(in: "Fold in the egg whites"))
    }

    func testQuotedTimeIsAllowed() {
        let explanation = StepExplanation(
            expandedText: "Cook for 20 minutes",
            whyItMatters: "Enough time is needed for flavors to meld.",
            commonMistake: "Not cooking long enough."
        )
        XCTAssertTrue(explanation.isGrounded(in: "Simmer 20 Minutes"))
    }

    func testInventedTimeInMistakeFieldIsRejected() {
        let explanation = StepExplanation(
            expandedText: "Mix for 5 minutes",
            whyItMatters: "Proper mixing ensures even distribution.",
            commonMistake: "Don't exceed 5 min"
        )
        XCTAssertFalse(explanation.isGrounded(in: "Simmer 20 minutes"))
    }
}
