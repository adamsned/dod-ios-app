import DODSupport
import Foundation
import WidgetKit

struct ShoppingListEntry: TimelineEntry {
    let date: Date
    /// nil => no active list (render the placeholder/config state).
    let state: ShoppingListWidgetState?

    static let placeholder = ShoppingListEntry(
        date: Date(timeIntervalSince1970: 1_700_000_000),
        state: ShoppingListWidgetState(
            listName: "Shopping List",
            total: 8,
            remaining: 5,
            unchecked: ["2 cups flour", "1 onion", "Butter", "Garlic", "Salt"].map {
                ShoppingListWidgetItem(id: UUID(), text: $0)
            }
        )
    )
}

struct ShoppingListTimelineProvider: TimelineProvider {
    private let refreshInterval: TimeInterval = 4 * 60 * 60

    func placeholder(in context: Context) -> ShoppingListEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (ShoppingListEntry) -> Void) {
        let entry = currentEntry()
        completion(context.isPreview && entry.state == nil ? .placeholder : entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ShoppingListEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .after(Date().addingTimeInterval(refreshInterval))))
    }

    private func currentEntry() -> ShoppingListEntry {
        ShoppingListEntry(date: Date(), state: ShoppingListWidgetBridge.read())
    }
}
