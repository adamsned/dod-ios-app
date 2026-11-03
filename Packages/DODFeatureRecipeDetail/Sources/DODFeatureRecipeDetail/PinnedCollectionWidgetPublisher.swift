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

    public func publish() async {
        guard let widgetStore else { return }
        let collections: [RecipeCollection]
        do {
            collections = try await store.collections()
        } catch {
            DODLog.persistence.error(
                "pinned-collection publish: read failed: \(String(describing: error))"
            )
            return
        }
        var out: [PinnedCollectionsWidgetSnapshot.Collection] = []
        for collection in collections {
            let recipes = (try? await store.recipes(inCollection: collection.id)) ?? []
            out.append(Self.toSnapshotCollection(collection, recipes: recipes))
        }
        do {
            try widgetStore.writePinnedCollections(
                PinnedCollectionsWidgetSnapshot(writtenAt: Date(), collections: out)
            )
        } catch {
            DODLog.app.error(
                "pinned-collection snapshot write failed: \(String(describing: error))"
            )
            return
        }
        reload?()
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
