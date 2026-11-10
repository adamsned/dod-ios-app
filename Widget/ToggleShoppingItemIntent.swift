import AppIntents
import DODSupport
import Foundation
import WidgetKit

/// DUT-167 — tap a checkbox in the Shopping List widget to mark the item bought.
struct ToggleShoppingItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Off Shopping Item"
    static let description = IntentDescription("Marks a shopping list item as bought.")
    static let isDiscoverable = false  // widget-only, hide from Shortcuts

    @Parameter(title: "Item ID") var itemID: String

    init() {}
    init(itemID: UUID) { self.itemID = itemID.uuidString }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: itemID) {
            ShoppingListWidgetBridge.markChecked(id)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: ShoppingListWidgetBridge.kind)
        return .result()
    }
}
