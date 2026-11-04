import Foundation
import Testing

@testable import DODSupport

@Suite("ShoppingListWidgetBridge") struct ShoppingListWidgetBridgeTests {

    static func freshDefaults() throws -> UserDefaults {
        let name = "dod.widget.shopping.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    struct Row {
        let id: UUID
        let ingredientText: String
        let recipeTitle: String
    }

    static func seed(
        _ defaults: UserDefaults,
        rows: [Row],
        checked: [UUID],
        alreadyHave: [UUID]
    ) throws {
        let items: [[String: Any]] = rows.map {
            [
                "id": $0.id.uuidString,
                "ingredientText": $0.ingredientText,
                "recipeTitle": $0.recipeTitle,
                "aisle": "produce",
            ]
        }
        let object: [String: Any] = [
            "items": items,
            "checkedIDs": checked.map(\.uuidString),
            "alreadyHaveIDs": alreadyHave.map(\.uuidString),
        ]
        let data = try JSONSerialization.data(withJSONObject: object)
        defaults.set(data, forKey: ShoppingListWidgetBridge.storageKey)
    }

    @Test func readReturnsNilWhenEmpty() throws {
        let defaults = try Self.freshDefaults()
        #expect(ShoppingListWidgetBridge.read(defaults: defaults) == nil)
    }
}
