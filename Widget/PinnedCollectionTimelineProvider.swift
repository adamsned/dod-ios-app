import DODSupport
import Foundation
import WidgetKit

struct PinnedCollectionEntry: TimelineEntry {
    enum State: Equatable {
        case notConfigured  // no collection chosen
        case missing  // chosen collection was deleted / not in snapshot
        case empty(name: String)  // collection has zero recipes
        case populated(PinnedCollectionsWidgetSnapshot.Collection)
    }
    let date: Date
    let state: State

    static let placeholder = PinnedCollectionEntry(
        date: Date(timeIntervalSince1970: 1_700_000_000),
        state: .populated(
            .init(
                id: UUID(),
                name: "Camping Dinners",
                totalCount: 3,
                recipes: [
                    .init(recipeID: -1, title: "Dutch Oven Chili", heroImageFilename: nil),
                    .init(recipeID: -2, title: "Peach Cobbler", heroImageFilename: nil),
                    .init(recipeID: -3, title: "Cast Iron Pizza", heroImageFilename: nil),
                ]
            )
        )
    )

    /// Pure, so it can be unit-tested if a test target is ever added.
    static func state(for collectionID: String?, in snapshot: PinnedCollectionsWidgetSnapshot?) -> State {
        guard let collectionID, let uuid = UUID(uuidString: collectionID) else { return .notConfigured }
        guard let collection = snapshot?.collection(id: uuid) else { return .missing }
        return collection.recipes.isEmpty ? .empty(name: collection.name) : .populated(collection)
    }
}

struct PinnedCollectionTimelineProvider: AppIntentTimelineProvider {
    private let refreshInterval: TimeInterval = 4 * 60 * 60

    func placeholder(in context: Context) -> PinnedCollectionEntry { .placeholder }

    func snapshot(for configuration: PinnedCollectionWidgetIntent, in context: Context) async -> PinnedCollectionEntry {
        let entry = entry(for: configuration)
        return entry.state == .notConfigured && context.isPreview ? .placeholder : entry
    }

    func timeline(
        for configuration: PinnedCollectionWidgetIntent,
        in context: Context
    ) async -> Timeline<PinnedCollectionEntry> {
        Timeline(
            entries: [entry(for: configuration)],
            policy: .after(Date().addingTimeInterval(refreshInterval))
        )
    }

    private func entry(for configuration: PinnedCollectionWidgetIntent) -> PinnedCollectionEntry {
        let snap = WidgetSnapshotStore()?.readPinnedCollections()
        return PinnedCollectionEntry(
            date: Date(),
            state: PinnedCollectionEntry.state(for: configuration.collection?.id, in: snap)
        )
    }
}
