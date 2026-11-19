import XCTest

@testable import DODSupport

final class BringListCoalPlannerTests: XCTestCase {

    func testOvenCount() {
        XCTAssertEqual(BringListCoalPlanner.ovenCount(servings: nil), 1)
        XCTAssertEqual(BringListCoalPlanner.ovenCount(servings: 8), 1)
        XCTAssertEqual(BringListCoalPlanner.ovenCount(servings: 9), 2)
        XCTAssertEqual(BringListCoalPlanner.ovenCount(servings: 0), 1)
    }

    func testBriquettesToPack() {
        // 12-inch oven at 350F gives 24 coals (diameter x 2), plus 50% = 36
        XCTAssertEqual(BringListCoalPlanner.briquettesToPack(servings: 8), 36)

        // For 16 servings, that's 2 ovens, so 2 * 24 + 50% = 48 + 24 = 72
        XCTAssertEqual(BringListCoalPlanner.briquettesToPack(servings: 16), 72)
    }
}
