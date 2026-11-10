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

    /// Adds `id` to `checkedIDs` without re-encoding items, so `aisle` and any future fields survive.
    /// Idempotent; returns false if the blob is missing or invalid.
    @discardableResult
    public static func markChecked(_ id: UUID, defaults: UserDefaults) -> Bool {
        guard let data = defaults.data(forKey: storageKey),
            var dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return false }
        var checked = dict["checkedIDs"] as? [String] ?? []
        if checked.contains(where: { UUID(uuidString: $0) == id }) { return true }
        checked.append(id.uuidString)
        dict["checkedIDs"] = checked
        guard let out = try? JSONSerialization.data(withJSONObject: dict) else { return false }
        defaults.set(out, forKey: storageKey)
        return true
    }

    public static func read() -> ShoppingListWidgetState? {
        guard let defaults = UserDefaults(suiteName: WidgetSnapshotConfig.appGroupIdentifier) else { return nil }
        return read(defaults: defaults)
    }

    @discardableResult
    public static func markChecked(_ id: UUID) -> Bool {
        guard let defaults = UserDefaults(suiteName: WidgetSnapshotConfig.appGroupIdentifier) else { return false }
        return markChecked(id, defaults: defaults)
    }
}
