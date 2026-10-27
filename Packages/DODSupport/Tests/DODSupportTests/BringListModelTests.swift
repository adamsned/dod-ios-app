import XCTest

@testable import DODSupport

final class BringListModelTests: XCTestCase {

    func testTogglePackedFlipsIsPacked() {
        // Given
        var bringList = BringList(items: [
            BringListItem(
                id: "tongs",
                name: "Tongs",
                category: .tools,
                isPacked: false
            )
        ])

        // When
        bringList.togglePacked(id: "tongs")

        // Then
        XCTAssertTrue(bringList.items[0].isPacked)

        // When
        bringList.togglePacked(id: "tongs")

        // Then
        XCTAssertFalse(bringList.items[0].isPacked)

        // When - calling with unknown id
        bringList.togglePacked(id: "unknown")

        // Then - should remain unchanged
        XCTAssertFalse(bringList.items[0].isPacked)
    }

    func testGroupedOrdersOvensFuelTools() {
        // Given
        let bringList = BringList(items: [
            BringListItem(
                id: "oven1",
                name: "Oven",
                category: .ovens,
                isPacked: false
            ),
            BringListItem(
                id: "fuel1",
                name: "Fuel",
                category: .fuel,
                isPacked: false
            ),
            BringListItem(
                id: "tools1",
                name: "Tools",
                category: .tools,
                isPacked: false
            ),
        ])

        // When
        let grouped = bringList.grouped()

        // Then
        XCTAssertEqual(grouped.map(\.category), [.ovens, .fuel, .tools])

        // Verify no empty groups appear
        XCTAssertTrue(grouped.allSatisfy { !$0.items.isEmpty })
    }
}
