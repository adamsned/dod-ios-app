import XCTest

@testable import DODSupport

final class ShoppingListWidgetBridgeMarkCheckedTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: "test-suite")
        XCTAssertNotNil(defaults, "Failed to create UserDefaults with test suite")
        defaults?.removeObject(forKey: ShoppingListWidgetBridge.storageKey)
        return defaults ?? UserDefaults()
    }

    private func seedData(_ defaults: UserDefaults, items: [[String: Any]]) {
        let blob: [String: Any] = [
            "items": items,
            "checkedIDs": [],
            "alreadyHaveIDs": [],
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: blob) else {
            XCTFail("Failed to serialize seed data")
            return
        }
        defaults.set(data, forKey: ShoppingListWidgetBridge.storageKey)
    }

    func testMarkCheckedThenReadDropsItem() {
        let defaults = freshDefaults()

        // Seed 2 items
        let items = [
            [
                "id": UUID().uuidString,
                "ingredientText": "Apples",
                "recipeTitle": "Fruit Salad",
                "aisle": "produce",
            ],
            [
                "id": UUID().uuidString,
                "ingredientText": "Bananas",
                "recipeTitle": "Fruit Salad",
                "aisle": "produce",
            ],
        ]
        seedData(defaults, items: items)

        // Mark first item as checked
        guard let idString = items[0]["id"] as? String,
            let firstId = UUID(uuidString: idString)
        else {
            XCTFail("Failed to get valid UUID from item")
            return
        }
        XCTAssertTrue(ShoppingListWidgetBridge.markChecked(firstId, defaults: defaults))

        // Read the state and verify only one item remains
        let state = ShoppingListWidgetBridge.read(defaults: defaults)
        XCTAssertNotNil(state)
        XCTAssertEqual(state?.remaining, 1)

        // Verify the marked item is not in unchecked list
        XCTAssertFalse(state?.unchecked.contains { $0.id == firstId } ?? false)
    }

    func testMarkCheckedPreservesAisleField() {
        let defaults = freshDefaults()

        // Seed items with aisle field
        let items = [
            [
                "id": UUID().uuidString,
                "ingredientText": "Apples",
                "recipeTitle": "Fruit Salad",
                "aisle": "produce",
            ],
            [
                "id": UUID().uuidString,
                "ingredientText": "Bananas",
                "recipeTitle": "Fruit Salad",
                "aisle": "produce",
            ],
        ]
        seedData(defaults, items: items)

        // Mark first item as checked
        guard let idString = items[0]["id"] as? String,
            let firstId = UUID(uuidString: idString)
        else {
            XCTFail("Failed to get valid UUID from item")
            return
        }
        XCTAssertTrue(ShoppingListWidgetBridge.markChecked(firstId, defaults: defaults))

        // Re-parse raw data and verify aisle field is preserved
        guard let data = defaults.data(forKey: ShoppingListWidgetBridge.storageKey),
            let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let rawItems = dict["items"] as? [[String: Any]]
        else {
            XCTFail("Failed to re-parse raw data")
            return
        }

        XCTAssertEqual(rawItems.count, 2)
        for item in rawItems {
            XCTAssertTrue(item.keys.contains("aisle"), "Item should preserve aisle field")
        }
    }

    func testMarkCheckedIsIdempotent() {
        let defaults = freshDefaults()

        // Seed one item
        let items = [
            [
                "id": UUID().uuidString,
                "ingredientText": "Apples",
                "recipeTitle": "Fruit Salad",
                "aisle": "produce",
            ]
        ]
        seedData(defaults, items: items)

        guard let idString = items[0]["id"] as? String,
            let itemId = UUID(uuidString: idString)
        else {
            XCTFail("Failed to get valid UUID from item")
            return
        }

        // Mark it checked (first time)
        XCTAssertTrue(ShoppingListWidgetBridge.markChecked(itemId, defaults: defaults))

        // Mark it checked again (should be idempotent)
        XCTAssertTrue(ShoppingListWidgetBridge.markChecked(itemId, defaults: defaults))

        // Verify checkedIDs contains the ID exactly once
        guard let data = defaults.data(forKey: ShoppingListWidgetBridge.storageKey),
            let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let checkedIDs = dict["checkedIDs"] as? [String]
        else {
            XCTFail("Failed to get checkedIDs")
            return
        }

        XCTAssertEqual(checkedIDs.count, 1)
        XCTAssertEqual(checkedIDs[0], itemId.uuidString)
    }

    func testMarkCheckedReturnsFalseWhenMissing() {
        let defaults = freshDefaults()

        // Fresh defaults should not have any data
        let id = UUID()
        XCTAssertFalse(ShoppingListWidgetBridge.markChecked(id, defaults: defaults))
    }
}
