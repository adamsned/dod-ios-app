import DODDomain
import DODPersistence
import DODSupport
import Foundation

/// DUT-172 — writes the Pinned Collection widget snapshot after collection/saved changes.
public struct PinnedCollectionWidgetPublisher: Sendable {
    public typealias ReloadHook = @Sendable () -> Void

    private let store: RecipeStore
    private let widgetStore: WidgetSnapshotStore?
    private let reload: ReloadHook?

    public init(
        store: RecipeStore,
        widgetStore: WidgetSnapshotStore? = WidgetSnapshotStore(),
        reload: ReloadHook? = nil
    ) {
        self.store = store
        self.widgetStore = widgetStore
        self.reload = reload
    }

    static func toSnapshotCollection(
        _ collection: RecipeCollection,
        recipes: [Recipe]
    ) -> PinnedCollectionsWidgetSnapshot.Collection {
        let top = recipes.prefix(PinnedCollectionsWidgetSnapshotConfig.maxRecipesPerCollection).map {
            PinnedCollectionsWidgetSnapshot.Recipe(
                recipeID: $0.id,
                title: $0.title,
                heroImageFilename: $0.heroImage.map { WidgetImageBridge.filename(for: $0) }
            )
        }
        return .init(
            id: collection.id,
            name: collection.name,
            totalCount: recipes.count,
            recipes: Array(top)
        )
    }
}
