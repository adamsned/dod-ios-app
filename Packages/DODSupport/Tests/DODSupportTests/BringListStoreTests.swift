import XCTest

@testable import DODSupport

final class BringListStoreTests: XCTestCase {
    func testLoadEmpty() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("empty.json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = BringListStore(fileURL: url)
        let list = store.load()
        XCTAssertTrue(list.items.isEmpty)
    }

    func testLoadInvalid() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("invalid.json")
        defer { try? FileManager.default.removeItem(at: url) }

        try "not json".write(to: url, atomically: true, encoding: .utf8)

        let store = BringListStore(fileURL: url)
        let list = store.load()
        XCTAssertTrue(list.items.isEmpty)
    }

    func testSaveAndLoad() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test.json")
        defer { try? FileManager.default.removeItem(at: url) }

        let original = BringList(items: [
            BringListItem(
                id: "test",
                name: "Test Item",
                category: .fuel,
                quantity: 2,
                isPacked: true
            )
        ])

        let store = BringListStore(fileURL: url)
        try store.save(original)

        let loaded = store.load()
        XCTAssertEqual(loaded.items.count, 1)
        XCTAssertEqual(loaded.items[0].name, "Test Item")
        XCTAssertTrue(loaded.items[0].isPacked)
    }

    func testMerge() throws {
        let existing = BringList(items: [
            BringListItem(id: "item1", name: "Item 1", category: .fuel, isPacked: true),
            BringListItem(id: "item2", name: "Item 2", category: .tools, isPacked: false),
        ])

        let fresh = BringList(items: [
            BringListItem(id: "item1", name: "Item 1", category: .fuel, isPacked: false),
            BringListItem(id: "item3", name: "Item 3", category: .tools, isPacked: false),
        ])

        let merged = BringListStore.merge(existing: existing, fresh: fresh)

        XCTAssertEqual(merged.items.count, 2)
        XCTAssertTrue(merged.items[0].isPacked)  // Should preserve packed state from existing
        XCTAssertFalse(merged.items[1].isPacked)  // Should not be packed since it wasn't in existing
    }
}
