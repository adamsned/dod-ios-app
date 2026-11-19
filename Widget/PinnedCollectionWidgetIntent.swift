import AppIntents
import DODSupport
import Foundation
import WidgetKit

/// DUT-172 — a collection the user can pin.
struct PinnedCollectionEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Collection" }
    static var defaultQuery = PinnedCollectionQuery()

    /// `RecipeCollection.id.uuidString`.
    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct PinnedCollectionQuery: EntityQuery {
    private func all() -> [PinnedCollectionEntity] {
        (WidgetSnapshotStore()?.readPinnedCollections()?.collections ?? [])
            .map { PinnedCollectionEntity(id: $0.id.uuidString, name: $0.name) }
    }
    func entities(for identifiers: [String]) async throws -> [PinnedCollectionEntity] {
        all().filter { identifiers.contains($0.id) }
    }
    func suggestedEntities() async throws -> [PinnedCollectionEntity] { all() }
}

struct PinnedCollectionWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Pinned Collection" }
    static var description: IntentDescription {
        IntentDescription("Choose which collection this widget shows.")
    }
    @Parameter(title: "Collection")
    var collection: PinnedCollectionEntity?
}
