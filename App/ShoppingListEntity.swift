import AppIntents
import CoreSpotlight
import DODFeatureSaved
import Foundation

/// `AppEntity` that exposes a Dutch Oven Daddy shopping list item to App Intents, Siri,
/// Spotlight, and the Shortcuts app.
///
/// Part of DUT-1015.
struct ShoppingListItemEntity: AppEntity, IndexedEntity {
    let id: UUID
    let text: String
    let recipeTitle: String
    let isChecked: Bool

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Shopping List Item")
    }
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(text)", subtitle: "\(recipeTitle)")
    }
    static let defaultQuery = ShoppingListItemEntityQuery()

    init(payload: ShoppingListItemPayload) {
        id = payload.id
        text = payload.text
        recipeTitle = payload.recipeTitle
        isChecked = payload.isChecked
    }
    var attributeSet: CSSearchableItemAttributeSet {
        let set = CSSearchableItemAttributeSet(contentType: .content)
        set.title = text
        set.displayName = text
        set.contentDescription = recipeTitle
        set.keywords = ["shopping list", "groceries", "Dutch Oven Daddy"]
        return set
    }
}

/// Pure payload type for `ShoppingListItemEntity`.
struct ShoppingListItemPayload: Sendable, Hashable, Identifiable {
    let id: UUID
    let text: String
    let recipeTitle: String
    let isChecked: Bool
}

/// Query side of the shopping list item entity. Resolves by id (used when an intent parameter
/// is rehydrated), supplies suggestions (used by Siri / Shortcuts builder),
/// and feeds Spotlight via `IndexedEntity`.
struct ShoppingListItemEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [ShoppingListItemEntity] {
        Self.payloads(from: ShoppingListStore()?.load())
            .filter { identifiers.contains($0.id) }
            .map(ShoppingListItemEntity.init(payload:))
    }
    func suggestedEntities() async throws -> [ShoppingListItemEntity] {
        Self.payloads(from: ShoppingListStore()?.load()).map(ShoppingListItemEntity.init(payload:))
    }
    func entities(matching string: String) async throws -> [ShoppingListItemEntity] {
        let needle = string.lowercased()
        return Self.payloads(from: ShoppingListStore()?.load())
            .filter { $0.text.lowercased().contains(needle) }
            .map(ShoppingListItemEntity.init(payload:))
    }
    /// Pure mapping (testable): snapshot -> payloads, skipping already-have ids.
    static func payloads(from snapshot: ShoppingListStore.Snapshot?) -> [ShoppingListItemPayload] {
        guard let snapshot else { return [] }
        let have = Set(snapshot.alreadyHaveIDs)
        let checked = Set(snapshot.checkedIDs)
        return snapshot.items.filter { !have.contains($0.id) }.map {
            ShoppingListItemPayload(
                id: $0.id,
                text: $0.ingredientText,
                recipeTitle: $0.recipeTitle,
                isChecked: checked.contains($0.id)
            )
        }
    }
}
