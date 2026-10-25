import AppIntents
import CoreSpotlight
import DODDomain
import DODPersistence
import DODSupport
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
    /// DUT-2255 — a small thumbnail made from hero bytes ALREADY on the phone, or
    /// nil (the entity then shows the `fork.knife` symbol). Never a remote URL:
    /// the Shortcuts app draws a tile per suggested recipe per App Shortcut, and
    /// remote thumbnails made it download dozens of photos to draw its list.
    var thumbnailData: Data?

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Recipe")
    }

    var displayRepresentation: DisplayRepresentation {
        // DUT-2255 — local thumbnail bytes or a symbol; never `.init(url:)` on
        // the remote hero (see `thumbnailData`).
        let image: DisplayRepresentation.Image =
            thumbnailData.map { .init(data: $0) } ?? .init(systemName: "fork.knife")
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
        self.thumbnailData = nil
    }

    /// DUT-2255 — entities with on-phone thumbnails filled in where the hero is
    /// already cached (downsampled once, then memoized for the process).
    static func withLocalThumbnails(_ payloads: [RecipeEntityPayload]) async -> [RecipeEntity] {
        var out: [RecipeEntity] = []
        out.reserveCapacity(payloads.count)
        for payload in payloads {
            var entity = RecipeEntity(payload: payload)
            entity.thumbnailData = await RecipeEntityThumbnails.shared.thumbnail(for: payload.heroImage)
            out.append(entity)
        }
        return out
    }

    /// DUT-1388 — back to the value payload (for the save / Shopping List paths).
    var payload: RecipeEntityPayload {
        RecipeEntityPayload(id: id, title: title, excerpt: excerpt, heroImage: heroImage, canonicalURL: canonicalURL)
    }

    /// Custom Spotlight attributes. The `IndexedEntity` protocol synthesizes
    /// a default `CSSearchableItemAttributeSet` from `displayRepresentation`,
    /// but we want the recipe excerpt searchable too and a stable content
    /// type so the user can spot DOD results in mixed Spotlight lists.
    ///
    /// DUT-412 — `thumbnailData` (LOCAL bytes) is set by the caller when the
    /// hero image is already in the disk cache; we deliberately do NOT set
    /// `thumbnailURL = heroImage` here — that's a remote https URL and
    /// CoreSpotlight never fetches remote thumbnails (the row rendered blank).
    /// The Siri `displayRepresentation` path keeps the remote URL (fine there).
    var attributeSet: CSSearchableItemAttributeSet {
        let set = CSSearchableItemAttributeSet(contentType: .content)
        set.title = title
        set.displayName = title
        set.contentDescription = excerpt
        set.keywords = ["recipe", "dutch oven", "cooking"]
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
        var payloads: [RecipeEntityPayload] = []
        for id in identifiers {
            if let payload = await RecipeEntityQuery.payload(id: id) {
                payloads.append(payload)
            }
        }
        return await RecipeEntity.withLocalThumbnails(payloads)
    }

    /// Entities suggested in the Shortcuts builder and Siri's recipe-name
    /// completion, AND the values iOS expands every parameterized App Shortcut
    /// over ("Cook <recipe>", "Save <recipe>", ...). DUT-2255 — a short list
    /// (``shortcutSuggestionPayloads()``, max 15), not the 60-recipe Spotlight
    /// pool: 4 recipe shortcuts x 60 recipes made up to 240 tiles for the
    /// Shortcuts app to draw.
    func suggestedEntities() async throws -> [RecipeEntity] {
        await RecipeEntity.withLocalThumbnails(try await RecipeEntityQuery.shortcutSuggestionPayloads())
    }

    /// Name match for `EntityStringQuery` (Siri transcriptions, and every
    /// keystroke in a Shortcuts recipe picker). DUT-2255 — matches recipes
    /// already on the phone (saved + recent) only, so typing never waits on the
    /// network; "Find a recipe" (``FindRecipesIntent``) still searches the site.
    func entities(matching string: String) async throws -> [RecipeEntity] {
        let pool = (try? await RecipeEntityQuery.suggestedPayloads()) ?? []
        let matches = RecipeEntityQuery.rank(local: pool, remote: [], query: string, limit: 10)
        return await RecipeEntity.withLocalThumbnails(matches)
    }

    /// DUT-2255 — how many suggestions iOS expands App Shortcuts over, and how
    /// many of those are reserved for recently viewed recipes.
    static let shortcutSuggestionLimit = 15
    static let shortcutRecentCount = 5

    /// DUT-2255 — the short App Shortcut suggestion list (see
    /// ``suggestedEntities()``).
    static func shortcutSuggestionPayloads() async throws -> [RecipeEntityPayload] {
        guard let store = AppIntentEnvironment.store else { return [] }
        let saved = (try? await store.savedRecipes()) ?? []
        let recents = (try? await store.recentlyViewed(limit: shortcutRecentCount)) ?? []
        return shortcutSuggestions(
            saved: saved.map(RecipeEntityPayload.fromRecipe),
            recents: recents.map(RecipeEntityPayload.fromRecipe)
        )
    }

    /// Pure (unit-tested): the 5 most recent first (what the cook is cooking
    /// now), then saved recipes, de-duplicated, capped at 15.
    static func shortcutSuggestions(
        saved: [RecipeEntityPayload],
        recents: [RecipeEntityPayload],
        limit: Int = shortcutSuggestionLimit,
        recentCount: Int = shortcutRecentCount
    ) -> [RecipeEntityPayload] {
        var seen: Set<Int> = []
        var out: [RecipeEntityPayload] = []
        for payload in recents.prefix(recentCount) + saved where out.count < limit {
            if seen.insert(payload.id).inserted { out.append(payload) }
        }
        return out
    }

    /// DUT-1388 — one recipe by id: the local cache first (network-free for
    /// anything saved or opened), then the site for a recipe never opened here.
    static func payload(id: Int) async -> RecipeEntityPayload? {
        if let recipe = try? await AppIntentEnvironment.store?.recipeWithoutTouching(id: id) {
            return .fromRecipe(recipe)
        }
        guard let item = try? await AppIntentEnvironment.actions?.fetchPost(id) else { return nil }
        return .fromListItem(item)
    }

    /// DUT-1388 — title search across saved + recent AND the site, strongest
    /// title match first. Local hits lead (they're the ones the cook knows);
    /// a network failure (offline) degrades to local-only.
    static func searchPayloads(query: String, limit: Int = 10) async -> [RecipeEntityPayload] {
        let local = (try? await suggestedPayloads()) ?? []
        let remote = ((try? await AppIntentEnvironment.actions?.searchRecipes(query)) ?? [])
            .map(RecipeEntityPayload.fromListItem)
        return rank(local: local, remote: remote, query: query, limit: limit)
    }

    /// Pure ranking for ``searchPayloads(query:limit:)``: keeps only TITLE
    /// matches (``TitleSearchMatcher`` — the same precision rule in-app search
    /// uses, so a body-only WP hit never wins), strongest tier first, local
    /// before remote within a tier, de-duplicated by id.
    static func rank(
        local: [RecipeEntityPayload],
        remote: [RecipeEntityPayload],
        query: String,
        limit: Int
    ) -> [RecipeEntityPayload] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }
        var seen: Set<Int> = []
        let scored = (local + remote).compactMap { payload -> (kind: TitleMatchKind, payload: RecipeEntityPayload)? in
            guard seen.insert(payload.id).inserted,
                let kind = TitleSearchMatcher.match(query: needle, title: payload.title)
            else { return nil }
            return (kind, payload)
        }
        // Swift's sort is stable, so local-before-remote order holds within a tier.
        return scored.sorted { $0.kind < $1.kind }.prefix(limit).map(\.payload)
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
