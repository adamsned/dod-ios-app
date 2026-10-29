import AppIntents
import DODFeatureSaved
import Foundation

// DUT-1950 — Siri / Shortcuts intents for the shopping list (part of DUT-1015).
// No em dashes in any dialog copy (it's user-facing).

/// Reads what is left (unchecked) on the shopping list and returns the items as entities.
struct ReadShoppingListIntent: AppIntent {

    static let title: LocalizedStringResource = "Read Shopping List"
    static let description = IntentDescription("Reads what is left on your shopping list.")

    /// Pure spoken summary (unit-tested).
    static func spokenSummary(from payloads: [ShoppingListItemPayload]) -> String {
        let remaining = payloads.filter { !$0.isChecked }.map(\.text)
        guard !remaining.isEmpty else { return "Your shopping list is empty." }
        let count = remaining.count
        return "You have \(count) item\(count == 1 ? "" : "s") left: " + remaining.joined(separator: ", ") + "."
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<[ShoppingListItemEntity]> {
        let payloads = ShoppingListItemEntityQuery.payloads(from: ShoppingListStore()?.load())
        return .result(
            value: payloads.map(ShoppingListItemEntity.init(payload:)),
            dialog: IntentDialog(stringLiteral: Self.spokenSummary(from: payloads))
        )
    }
}

/// Adds a free-text item to the shopping list. Named distinctly from `AddRecipeToShoppingListIntent`.
/// A `String` parameter cannot sit in an App Shortcut phrase; ticket 4 handles that.
struct AddShoppingListItemIntent: AppIntent {

    static let title: LocalizedStringResource = "Add to Shopping List"

    @Parameter(title: "Item")
    var item: String

    /// Pure dialog copy (unit-tested).
    static func dialog(item: String, added: Bool) -> String {
        added ? "Added \(item) to your list." : "\(item) is already on your list."
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let added = ShoppingListStore()?.addItem(text: item) ?? false
        return .result(dialog: IntentDialog(stringLiteral: Self.dialog(item: item, added: added)))
    }
}
