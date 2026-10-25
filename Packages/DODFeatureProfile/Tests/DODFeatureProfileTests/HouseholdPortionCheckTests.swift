import XCTest

@testable import DODFeatureProfile

final class HouseholdPortionCheckTests: XCTestCase {

    func testVerdictWith2AdultsAnd1LittleKidAndServings2() {
        // 2 adults plus 1 littleKid (need 2.5, rounds up to 3) with servings 2 gives .scaleUp(needed: 3, have: 2)
        let members = [
            HouseholdMember(id: "1", name: "Adult 1", ageBand: .teenOrAdult),
            HouseholdMember(id: "2", name: "Adult 2", ageBand: .teenOrAdult),
            HouseholdMember(id: "3", name: "Little Kid", ageBand: .littleKid),
        ]
        let verdict = HouseholdPortionCheck.verdict(members: members, servings: 2)
        XCTAssertEqual(verdict, .scaleUp(needed: 3, have: 2))
    }

    func testVerdictWith2AdultsAnd1LittleKidAndServings3() {
        // Same roster with servings 3 gives .justEnough
        let members = [
            HouseholdMember(id: "1", name: "Adult 1", ageBand: .teenOrAdult),
            HouseholdMember(id: "2", name: "Adult 2", ageBand: .teenOrAdult),
            HouseholdMember(id: "3", name: "Little Kid", ageBand: .littleKid),
        ]
        let verdict = HouseholdPortionCheck.verdict(members: members, servings: 3)
        XCTAssertEqual(verdict, .justEnough)
    }

    func testVerdictWith2AdultsAnd1LittleKidAndServings4() {
        // Same roster with servings 4 gives .leftovers(extraPortions: 1)
        let members = [
            HouseholdMember(id: "1", name: "Adult 1", ageBand: .teenOrAdult),
            HouseholdMember(id: "2", name: "Adult 2", ageBand: .teenOrAdult),
            HouseholdMember(id: "3", name: "Little Kid", ageBand: .littleKid),
        ]
        let verdict = HouseholdPortionCheck.verdict(members: members, servings: 4)
        XCTAssertEqual(verdict, .leftovers(extraPortions: 1))
    }

    func testVerdictWithNilServings() {
        // servings nil gives .noData
        let members = [
            HouseholdMember(id: "1", name: "Adult 1", ageBand: .teenOrAdult),
            HouseholdMember(id: "2", name: "Adult 2", ageBand: .teenOrAdult),
        ]
        let verdict = HouseholdPortionCheck.verdict(members: members, servings: nil)
        XCTAssertEqual(verdict, .noData)
    }

    func testVerdictWithEmptyRoster() {
        // an empty roster gives .noData
        let verdict = HouseholdPortionCheck.verdict(members: [], servings: 3)
        XCTAssertEqual(verdict, .noData)
    }

    func testMessageForNoData() {
        // message(for: .noData) == nil
        let message = HouseholdPortionCheck.message(for: .noData)
        XCTAssertNil(message)
    }
}
