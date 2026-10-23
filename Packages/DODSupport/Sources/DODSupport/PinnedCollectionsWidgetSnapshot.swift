import Foundation

/// DUT-172 — wire format for the configurable Pinned Collection widget.
public struct PinnedCollectionsWidgetSnapshot: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let writtenAt: Date
    public let collections: [Collection]

    public init(
        schemaVersion: Int = PinnedCollectionsWidgetSnapshot.currentSchemaVersion,
        writtenAt: Date,
        collections: [Collection]
    ) {
        self.schemaVersion = schemaVersion
        self.writtenAt = writtenAt
        self.collections = collections
    }

    public struct Collection: Codable, Sendable, Equatable, Identifiable {
        public let id: UUID  // RecipeCollection.id
        public let name: String
        public let totalCount: Int  // true size, recipes is capped
        public let recipes: [Recipe]  // first N, in collection order
        public init(id: UUID, name: String, totalCount: Int, recipes: [Recipe]) {
            self.id = id
            self.name = name
            self.totalCount = totalCount
            self.recipes = recipes
        }
    }

    public struct Recipe: Codable, Sendable, Equatable, Identifiable {
        public let recipeID: Int
        public let title: String
        public let heroImageFilename: String?
        public var id: Int { recipeID }
        public init(recipeID: Int, title: String, heroImageFilename: String?) {
            self.recipeID = recipeID
            self.title = title
            self.heroImageFilename = heroImageFilename
        }
        /// `dod://recipe/<id>`; nil for non-positive ids (placeholder rows).
        public var deepLinkURL: URL? {
            guard recipeID > 0 else { return nil }
            return URL(string: "dod://recipe/\(recipeID)")
        }
    }

    public func collection(id: UUID) -> Collection? { collections.first { $0.id == id } }
}

public enum PinnedCollectionsWidgetSnapshotConfig {
    public static let userDefaultsKey = "dod.widget.pinnedCollections.v1"
    /// Large widget shows 6, medium 3; both take prefix(N) client-side.
    public static let maxRecipesPerCollection = 6
}
