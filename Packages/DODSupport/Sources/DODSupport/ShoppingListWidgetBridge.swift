import Foundation

public struct ShoppingListWidgetItem: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let text: String
    public init(id: UUID, text: String) {
        self.id = id
        self.text = text
    }
}

public struct ShoppingListWidgetState: Equatable, Sendable {
    public let listName: String
    public let total: Int
    public let remaining: Int
    public let unchecked: [ShoppingListWidgetItem]
    public init(listName: String, total: Int, remaining: Int, unchecked: [ShoppingListWidgetItem]) {
        self.listName = listName
        self.total = total
        self.remaining = remaining
        self.unchecked = unchecked
    }
}

public enum ShoppingListWidgetBridge {
    /// Must equal `ShoppingListStore.key`.
    public static let storageKey = "dod.shoppingList.v1"
    public static let kind = "ShoppingListWidget"

    private struct Blob: Decodable {
        struct Row: Decodable {
            let id: UUID
            let ingredientText: String
            let recipeTitle: String
        }
        let items: [Row]
        let checkedIDs: [UUID]
        let alreadyHaveIDs: [UUID]
    }

    /// nil when no list is stored, it cannot be decoded, or it has no visible rows.
    public static func read(defaults: UserDefaults) -> ShoppingListWidgetState? {
        guard let data = defaults.data(forKey: storageKey),
            let blob = try? JSONDecoder().decode(Blob.self, from: data)
        else { return nil }
        let hidden = Set(blob.alreadyHaveIDs)
        let visible = blob.items.filter { !hidden.contains($0.id) }
        guard !visible.isEmpty else { return nil }
        let titles = Set(visible.map(\.recipeTitle))
        var listName = "Shopping List"
        if titles.count == 1, let only = titles.first { listName = only }
        let checked = Set(blob.checkedIDs)
        let unchecked =
            visible
            .filter { !checked.contains($0.id) }
            .map { ShoppingListWidgetItem(id: $0.id, text: $0.ingredientText) }
        return ShoppingListWidgetState(
            listName: listName,
            total: visible.count,
            remaining: unchecked.count,
            unchecked: unchecked
        )
    }
}
