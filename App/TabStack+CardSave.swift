import DODDomain
import DODFeatureRecipeDetail
import DODPersistence
import DODSupport

// The shared card long-press save path + the Recipe → RecipeListItem projection,
// extracted from `TabStack.swift` so that file stays under the SwiftLint
// `file_length` cap.
extension TabStack {

    /// DUT-693 (PR7) — copy for the transient toast shown when a long-press card
    /// save fails to persist (`saveFromCard` returned `false`). Mirrors the
    /// DUT-549 deep-link failure snackbar: plain and non-blaming. No em dashes.
    static let saveFailedMessage = "Couldn't save that recipe. Please try again."

    /// US-34 / AC-34.2 / AC-34.3 — execute the same save side-effect as
    /// the recipe-detail nav-bar bookmark tap (AC-4.7 / AC-5.1), invoked
    /// from a `RecipeCard`'s long-press context menu. Caches the listItem
    /// first so freshly-fetched REST hits (Search/Categories) have a row
    /// to mutate, then toggles `isSaved`, then republishes the
    /// saved-recipes widget snapshot so the home-screen widget timeline
    /// refreshes the same frame the user expects.
    ///
    /// DUT-629 — returns `true` iff the store write succeeded. The card views
    /// flip their optimistic `savedRecipeIDs` membership BEFORE calling `onSave`;
    /// on a `false` return they re-invert it so a failed write doesn't strand the
    /// menu label (and the widget snapshot) showing a save that never persisted.
    @discardableResult
    static func saveFromCard(
        item: RecipeListItem,
        store: RecipeStore,
        publisher: SavedRecipesWidgetPublisher
    ) async -> Bool {
        do {
            try await store.cache(listItem: item)
            _ = try await store.toggleSaved(id: item.id)
        } catch {
            DODLog.persistence.error("save-from-card failed: \(String(describing: error))")
            return false
        }
        // T-770 / CL-167 (DUT-76) — `publisher` is built by
        // `AppDependencies.savedWidgetPublisher()` with the hero-image
        // prefetcher, so saving from a card (where the recipe's hero bytes are
        // usually not cached yet) still bridges the photo into the widget.
        await publisher.publish()
        return true
    }

    static func listItem(from recipe: Recipe) -> RecipeListItem {
        RecipeListItem(
            id: recipe.id,
            title: recipe.title,
            excerpt: recipe.excerpt,
            heroImage: recipe.heroImage,
            publishedAt: recipe.publishedAt,
            totalTimeDisplay: nil,
            canonicalURL: recipe.canonicalURL
        )
    }
}
