import AppIntents
import CoreSpotlight
import DODDomain
import DODSupport
import Foundation

/// DUT-1388 — a Saved-tab collection ("Weeknight Dinners") exposed to Siri,
/// Shortcuts, and Spotlight, so "Open my Weeknight Dinners collection in Dutch
/// Oven Daddy" lands on the Saved tab narrowed to it.
struct CollectionEntity: AppEntity, IndexedEntity {

    let id: UUID
    let name: String
    let recipeCount: Int

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Collection")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(Self.countText(recipeCount))",
            image: .init(systemName: "folder.fill")
        )
    }

    static let defaultQuery = CollectionEntityQuery()

    init(collection: RecipeCollection) {
        self.id = collection.id
        self.name = collection.name
        self.recipeCount = collection.recipeCount
    }

    /// "1 recipe" / "4 recipes".
    static func countText(_ count: Int) -> String {
        count == 1 ? "1 recipe" : "\(count) recipes"
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let set = CSSearchableItemAttributeSet(contentType: .content)
        set.title = name
        set.displayName = name
        set.contentDescription = "Saved recipe collection, \(Self.countText(recipeCount))"
        set.keywords = ["collection", "saved", "recipes"]
        return set
    }
}

struct CollectionEntityQuery: EntityQuery, EntityStringQuery {

    func entities(for identifiers: [CollectionEntity.ID]) async throws -> [CollectionEntity] {
        let wanted = Set(identifiers)
        return try await Self.all().filter { wanted.contains($0.id) }
    }

    func suggestedEntities() async throws -> [CollectionEntity] {
        try await Self.all()
    }

    func entities(matching string: String) async throws -> [CollectionEntity] {
        Self.match(try await Self.all(), query: string)
    }

    /// Every collection, in the cook's shelf order.
    static func all() async throws -> [CollectionEntity] {
        guard let store = AppIntentEnvironment.store else { return [] }
        return try await store.collections().map(CollectionEntity.init(collection:))
    }

    /// Pure name match (unit-tested): the same title-precision rule as recipe
    /// search, strongest match first, shelf order breaking ties.
    static func match(_ pool: [CollectionEntity], query: String) -> [CollectionEntity] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }
        // Stable sort: shelf order holds within a match tier.
        return pool
            .compactMap { entity in
                TitleSearchMatcher.match(query: needle, title: entity.name).map { (kind: $0, entity: entity) }
            }
            .sorted { $0.kind < $1.kind }
            .map(\.entity)
    }
}

/// Open the Saved tab narrowed to one collection. An `OpenIntent`, so tapping a
/// collection in Spotlight or a Siri result runs it too.
struct OpenCollectionIntent: OpenIntent {

    static let title: LocalizedStringResource = "Open Collection"
    static let description = IntentDescription(
        "Opens one of your saved recipe collections."
    )

    static let openAppWhenRun: Bool = true

    @Parameter(title: "Collection", requestValueDialog: "Which collection?")
    var target: CollectionEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$target)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        DeepLinkDispatcher.shared.dispatch(.openCollection(id: target.id))
        return .result()
    }
}
