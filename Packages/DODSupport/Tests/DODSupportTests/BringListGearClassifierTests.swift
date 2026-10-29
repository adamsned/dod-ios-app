import XCTest

@testable import DODSupport

final class BringListGearClassifierTests: XCTestCase {
    func testClassify() {
        XCTAssertEqual(BringListGearClassifier.classify("12-inch Dutch oven"), .ovens)
        XCTAssertEqual(BringListGearClassifier.classify("Charcoal chimney starter"), .fuel)
        XCTAssertEqual(BringListGearClassifier.classify("Leather gloves"), .tools)
        XCTAssertEqual(BringListGearClassifier.classify("Folding table"), .transport)
        XCTAssertEqual(BringListGearClassifier.classify(""), .other)
        XCTAssertEqual(BringListGearClassifier.classify("Spatula"), .other)
    }
}
