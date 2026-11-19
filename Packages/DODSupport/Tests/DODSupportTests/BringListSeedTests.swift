import DODDomain
import XCTest

@testable import DODSupport

final class BringListSeedTests: XCTestCase {
    func testDuplicateNamesCollapse() {
        let list = BringList.seed(
            equipment: [Equipment(name: "Tongs"), Equipment(name: " tongs ")],
            totalServings: 4
        )
        XCTAssertEqual(list.items.filter { $0.id == "tongs" }.count, 1)
    }

    func testFirstImageWins() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/tongs.png"))
        let list = BringList.seed(
            equipment: [Equipment(name: "Tongs", imageURL: url), Equipment(name: "tongs")],
            totalServings: 4
        )
        XCTAssertEqual(list.items.first { $0.id == "tongs" }?.imageURL, url)
    }

    func testBlankNameSkipped() {
        let list = BringList.seed(equipment: [Equipment(name: "   ")], totalServings: 4)
        XCTAssertFalse(list.items.contains { $0.id.isEmpty })
        XCTAssertFalse(list.items.contains { $0.name.trimmingCharacters(in: .whitespaces).isEmpty })
    }

    func testCoalQuantity() {
        let list = BringList.seed(equipment: [], totalServings: 16)
        let coal = list.items.first { $0.id == "charcoal briquettes" }
        XCTAssertEqual(coal?.quantity, BringListCoalPlanner.briquettesToPack(servings: 16))
        XCTAssertEqual(coal?.category, .fuel)
    }

    func testDefaultDutchOvenAdded() {
        let list = BringList.seed(equipment: [], totalServings: 16)
        XCTAssertEqual(list.items.first { $0.name == "Dutch oven" }?.quantity, 2)
    }

    func testNoDefaultOvenWhenEquipmentHasOven() {
        let list = BringList.seed(
            equipment: [Equipment(name: "12 inch Dutch oven")],
            totalServings: 16
        )
        XCTAssertFalse(list.items.contains { $0.id == "dutch oven" })
        XCTAssertEqual(list.items.filter { $0.category == .ovens }.count, 1)
    }
}
