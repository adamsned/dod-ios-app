import AppIntents
import CoreSpotlight
import DODDomain
import DODPersistence
import Foundation

/// `AppEntity` that exposes a Dutch Oven Daddy recipe to App Intents, Siri,
/// Spotlight, and the Shortcuts app.
///
/// Spec trace: US-10 / AC-10.1. Backed by `RecipeStore` saved + recently
/// viewed rows via ``RecipeEntityQuery``.
struct RecipeEntity: AppEntity, IndexedEntity {

    let id: Int
    let title: String
    let excerpt: String
    let heroImage: URL?
    let canonicalURL: URL?

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Recipe")
    }

    var displayRepresentation: DisplayRepresentation {
        // Use the canonical hero URL when present so Siri's UI can render a
        // thumbnail without re-fetching. DisplayRepresentation.Image accepts
        // a URL via the `.url(_:)` initializer added in iOS 17.
        let image: DisplayRepresentation.Image? = heroImage.map { .init(url: $0) }
        return DisplayRepresentation(
            title: "\(title)",
            subtitle: excerpt.isEmpty ? nil : "\(excerpt)",
            image: image
        )
    }

    static let defaultQuery = RecipeEntityQuery()
}

extension RecipeEntity {
    init(payload: RecipeEntityPayload) {
        self.id = payload.id
        self.title = payload.title
        self.excerpt = payload.excerpt
        self.heroImage = payload.heroImage
        self.canonicalURL = payload.canonicalURL
    }

    /// Custom Spotlight attributes. The `IndexedEntity` protocol synthesizes
    /// a default `CSSearchableItemAttributeSet` from `displayRepresentation`,
    /// but we want the recipe excerpt searchable too and a stable content
    /// type so the user can spot DOD results in mixed Spotlight lists.
    var attributeSet: CSSearchableItemAttributeSet {
        let set = CSSearchableItemAttributeSet(contentType: .content)
        set.title = title
        set.displayName = title
        set.contentDescription = excerpt
        set.keywords = ["recipe", "dutch oven", "cooking"]
        if let heroImage {
            set.thumbnailURL = heroImage
        }
        return set
    }
}

/// Query side of the entity. Resolves by id (used when an intent parameter
/// is rehydrated), supplies suggestions (used by Siri / Shortcuts builder),
/// and feeds Spotlight via `IndexedEntity`.
struct RecipeEntityQuery: EntityQuery, EntityStringQuery {

    /// Look up specific entities by id. Called when the system has stored
    /// an entity identifier and needs to re-fetch the full payload.
    func entities(for identifiers: [RecipeEntity.ID]) async throws -> [RecipeEntity] {
        guard let store = AppIntentEnvironment.store else { return [] }
        var result: [RecipeEntity] = []
        for id in identifiers {
            if let recipe = try? await store.recipeWithoutTouching(id: id) {
                result.append(RecipeEntity(payload: .fromRecipe(recipe)))
            }
        }
        return result
    }

    /// Entities suggested in the Shortcuts builder and Siri's recipe-name
    /// completion. We surface every saved recipe plus the recent LRU.
    func suggestedEntities() async throws -> [RecipeEntity] {
        try await RecipeEntityQuery.suggestedPayloads().map(RecipeEntity.init(payload:))
    }

    /// Fuzzy-name match for `EntityStringQuery`. The system passes the
    /// raw transcription (e.g. "bourbon berry cake") and expects matching
    /// entities back. We do a case-insensitive contains across saved +
    /// recent — keeping the surface small means simple linear search is
    /// fine here.
    func entities(matching string: String) async throws -> [RecipeEntity] {
        let needle = string.lowercased()
        let pool = try await RecipeEntityQuery.suggestedPayloads()
        return
            pool
            .filter { $0.title.lowercased().contains(needle) }
            .map(RecipeEntity.init(payload:))
    }

    /// Shared payload assembly used by suggestions, string match, and
    /// Spotlight indexing. Deduplicates by id (a saved recipe is also a
    /// recent one) and caps at a sensible budget for Siri's UI.
    static func suggestedPayloads(limit: Int = 60) async throws -> [RecipeEntityPayload] {
        guard let store = AppIntentEnvironment.store else { return [] }
        let saved = (try? await store.savedRecipes()) ?? []
        let recents = (try? await store.recentlyViewed(limit: limit)) ?? []
        // DUT-406: reserve a slice for recently-viewed so a power user with ≥limit
        // saved recipes still gets recents represented in Siri/Spotlight (US-10).
        // The old loop filled entirely from `saved` first. Saved up to (limit -
        // recentsBudget), then recents, then any leftover saved.
        let recentsBudget = max(limit / 3, 1)
        var seen: Set<Int> = []
        var out: [RecipeEntityPayload] = []
        func fill(_ recipes: [Recipe], upTo cap: Int) {
            for recipe in recipes where !seen.contains(recipe.id) && out.count < cap {
                seen.insert(recipe.id)
                out.append(.fromRecipe(recipe))
            }
        }
        fill(saved, upTo: limit - recentsBudget)
        fill(recents, upTo: limit)
        fill(saved, upTo: limit)
        return out
    }
}
