import XCTest

@testable import DODFeatureFeed

final class CookoutRecapViewTests: XCTestCase {
    func testClampedCoverIndexHandlesBounds() {
        // Test case 1: index 5 with photoCount 3 should return 2 (max valid index)
        XCTAssertEqual(CookoutRecapView.clampedCoverIndex(5, photoCount: 3), 2)

        // Test case 2: index -1 with photoCount 3 should return 0 (min valid index)
        XCTAssertEqual(CookoutRecapView.clampedCoverIndex(-1, photoCount: 3), 0)

        // Test case 3: index 0 with photoCount 0 should return 0 (empty list case)
        XCTAssertEqual(CookoutRecapView.clampedCoverIndex(0, photoCount: 0), 0)
    }
}
