import AppIntents
import CoreSpotlight
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
        }
        DODShortcuts.updateAppShortcutParameters()
    }
}
