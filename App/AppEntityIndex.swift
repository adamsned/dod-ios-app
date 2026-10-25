import AppIntents
import CoreSpotlight
import Foundation

/// DUT-1388 — keeps the App Intents side of search current: the collections in
/// Spotlight (as `IndexedEntity`s) and the entity names Siri matches in App
/// Shortcut phrases ("Open my <collection> collection", "Save <recipe>").
/// Run with every Spotlight reindex (launch + foreground).
///
/// DUT-2255 — but it only TELLS iOS when something changed. Each
/// `updateAppShortcutParameters()` makes iOS re-expand every parameterized App
/// Shortcut over the suggestions, and calling it on every foreground kept the
/// Shortcuts app busy rebuilding the same tiles. A signature of the suggestion
/// ids + collections gates both that call and the collection re-index.
@MainActor
enum AppEntityIndex {

    /// The signature last pushed to the system this process (nil = never).
    private static var lastSignature: String?

    static func refresh() async {
        let suggestions = (try? await RecipeEntityQuery.shortcutSuggestionPayloads()) ?? []
        let collections = (try? await CollectionEntityQuery.all()) ?? []
        let current = signature(recipeIDs: suggestions.map(\.id), collections: collections)
        guard current != lastSignature else { return }
        if #available(iOS 18, *) {
            let index = CSSearchableIndex.default()
            // Replace wholesale so a deleted or renamed collection doesn't linger.
            try? await index.deleteAppEntities(ofType: CollectionEntity.self)
            if !collections.isEmpty {
                try? await index.indexAppEntities(collections)
            }
        }
        DODShortcuts.updateAppShortcutParameters()
        lastSignature = current
    }

    /// Pure (unit-tested): changes exactly when the App Shortcut suggestions or a
    /// collection's identity, name, or recipe count change.
    nonisolated static func signature(recipeIDs: [Int], collections: [CollectionEntity]) -> String {
        let recipes = recipeIDs.map(String.init).joined(separator: ",")
        let shelf = collections.map { "\($0.id.uuidString):\($0.name):\($0.recipeCount)" }.joined(separator: "|")
        return recipes + "#" + shelf
    }
}
