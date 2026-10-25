import DODSupport
import XCTest

@testable import DODFeatureFeed

final class FirstCookQuizViewTests: XCTestCase {

    func testMakeIntakeDropsSizeWhenNoOven() {
        let intake = FirstCookQuizView.makeIntake(
            hasDutchOven: false,
            ovenSize: 12,
            setup: .both,
            experience: .none
        )

        XCTAssertFalse(intake.hasDutchOven)
        XCTAssertNil(intake.ovenSizeInches)
        XCTAssertEqual(intake.setup, .both)
        XCTAssertEqual(intake.experience, .none)
    }

    func testMakeIntakeKeepsSizeWhenOven() {
        let intake = FirstCookQuizView.makeIntake(
            hasDutchOven: true,
            ovenSize: 12,
            setup: .both,
            experience: .none
        )

        XCTAssertTrue(intake.hasDutchOven)
        XCTAssertEqual(intake.ovenSizeInches, 12)
        XCTAssertEqual(intake.setup, .both)
        XCTAssertEqual(intake.experience, .none)
    }
}
