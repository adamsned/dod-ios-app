import AppIntents
import CoreSpotlight
import DODFeatureSaved
import Foundation

/// DUT-1388 — keeps the App Intents side of search current: the collections in
/// Spotlight (as `IndexedEntity`s) and the entity names Siri matches in App
/// Shortcut phrases ("Open my <collection> collection", "Save <recipe>").
/// Run with every Spotlight reindex (launch + foreground).
enum AppEntityIndex {

    static func refresh() async {
        if #available(iOS 18, *) {
            let collections = (try? await CollectionEntityQuery.all()) ?? []
            let index = CSSearchableIndex.default()
            // Replace wholesale so a deleted or renamed collection doesn't linger.
            try? await index.deleteAppEntities(ofType: CollectionEntity.self)
            if !collections.isEmpty {
                try? await index.indexAppEntities(collections)
            }
            // DUT-1015 — shopping list items join the semantic index.
            let items = AppEntityIndex.shoppingEntities()
            try? await index.deleteAppEntities(ofType: ShoppingListItemEntity.self)
            if !items.isEmpty {
                try? await index.indexAppEntities(items)
            }
        }
        DODShortcuts.updateAppShortcutParameters()
    }

    /// Unchecked, not-already-have list rows as entities (pure over the snapshot).
    static func shoppingEntities(
        from snapshot: ShoppingListStore.Snapshot? = ShoppingListStore()?.load()
    ) -> [ShoppingListItemEntity] {
        ShoppingListItemEntityQuery.payloads(from: snapshot)
            .filter { !$0.isChecked }
            .map(ShoppingListItemEntity.init(payload:))
    }
}
