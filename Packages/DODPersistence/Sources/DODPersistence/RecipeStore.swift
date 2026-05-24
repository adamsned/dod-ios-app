import DODDomain
import Foundation
import SwiftData

/// Persistent store owning every `CachedRecipe`, `CachedListPage`, and
/// `CachedImage`. Exposed as a `@ModelActor` so its `ModelContext` runs on
/// a dedicated executor — view models can call from any thread.
///
/// Spec trace: AC-1.6 (offline list hydration), AC-1.7 (blocklist),
/// AC-5.1 (save/unsave), AC-5.2 (offline pre-download), AC-5.3 (Saved tab),
/// AC-5.4 (offline detail), NFR-1/NFR-2 (cache budgets).
@ModelActor
public actor RecipeStore {

    public static let unsavedLRUCap = 100
    public static let imageBudgetBytes: Int = 200 * 1_024 * 1_024

    // MARK: - List item cache

    /// Insert-or-update a list item. Sets `lastViewedAt` so LRU sees it as fresh.
    public func cache(listItem: RecipeListItem) throws {
        let existing = try fetchRecipe(id: listItem.id)
        if let existing {
            existing.title = listItem.title
            existing.excerptText = listItem.excerpt
            existing.heroImageURLString = listItem.heroImage?.absoluteString
            // Update canonical URL when REST returns it — critical for
            // recipe-detail navigation (spec AC-4.11 + CL-4). Only overwrite
            // when a non-empty value is available so we don't clobber a good
            // existing value with an empty one.
            if let canonicalURL = listItem.canonicalURL {
                existing.canonicalURLString = canonicalURL.absoluteString
            }
            existing.lastViewedAt = .now
            // Successful re-fetch clears any prior blocklist entry (AC-1.7 reset
            // on pull-to-refresh).
            existing.jsonLDFailedAt = nil
        } else {
            modelContext.insert(
                CachedRecipe(
                    id: listItem.id,
                    slug: "",
                    title: listItem.title,
                    excerptText: listItem.excerpt,
                    canonicalURLString: listItem.canonicalURL?.absoluteString ?? "",
                    heroImageURLString: listItem.heroImage?.absoluteString,
                    publishedAt: listItem.publishedAt,
                    lastViewedAt: .now
                )
            )
        }
        try modelContext.save()
        try evictIfNeeded()
    }

    /// Bulk cache a list response so list screens can hydrate offline (AC-1.6).
    public func cache(listItems: [RecipeListItem]) throws {
        for item in listItems {
            try cache(listItem: item)
        }
    }

    // MARK: - Detail merge after JSON-LD parse

    /// Merge JSON-LD-derived detail fields into a cached recipe. If the row
    /// doesn't exist yet, create it from the canonical fields.
    public func mergeDetail(_ recipe: Recipe) throws {
        let existing = try fetchRecipe(id: recipe.id)
        let target: CachedRecipe
        if let existing {
            target = existing
        } else {
            target = CachedRecipe(
                id: recipe.id,
                slug: recipe.slug,
                title: recipe.title,
                excerptText: recipe.excerpt,
                canonicalURLString: recipe.canonicalURL.absoluteString,
                heroImageURLString: recipe.heroImage?.absoluteString,
                heroImageLargeURLString: recipe.heroImageLargeURL?.absoluteString,
                publishedAt: recipe.publishedAt
            )
            modelContext.insert(target)
        }

        target.slug = recipe.slug
        target.canonicalURLString = recipe.canonicalURL.absoluteString
        target.heroImageLargeURLString =
            recipe.heroImageLargeURL?.absoluteString
            ?? target.heroImageLargeURLString
        target.categoryIDs = recipe.categoryIDs.isEmpty ? target.categoryIDs : recipe.categoryIDs
        target.ingredientsJSON = try JSONEncoder().encode(recipe.ingredients)
        target.instructionsJSON = try JSONEncoder().encode(recipe.instructions)
        target.nutritionJSON = recipe.nutrition.flatMap { try? JSONEncoder().encode($0) }
        target.videoJSON = recipe.video.flatMap { try? JSONEncoder().encode($0) }
        target.prepSeconds = recipe.prepTime.map(Self.secondsOf)
        target.cookSeconds = recipe.cookTime.map(Self.secondsOf)
        target.totalSeconds = recipe.totalTime.map(Self.secondsOf)
        target.servings = recipe.servings
        target.lastViewedAt = .now
        target.jsonLDParsedAt = .now
        target.jsonLDFailedAt = nil

        // US-12 / AC-12.1: keep the local ingredient index in sync.
        try replaceIngredientIndexRows(forRecipeID: recipe.id, with: recipe.ingredients)

        try modelContext.save()
    }

    /// Read a recipe back, stitched into a Domain.Recipe.
    public func recipe(id: Int) throws -> Recipe? {
        guard let row = try fetchRecipe(id: id) else { return nil }
        return Self.toDomain(row)
    }

    // MARK: - Save / unsave (AC-5.1)

    public func isSaved(id: Int) throws -> Bool {
        try fetchRecipe(id: id)?.isSaved ?? false
    }

    @discardableResult
    public func toggleSaved(id: Int) throws -> Bool {
        guard let row = try fetchRecipe(id: id) else { return false }
        row.isSaved.toggle()
        try modelContext.save()
        // Eviction only meaningful when transitioning saved -> unsaved.
        try evictIfNeeded()
        return row.isSaved
    }

    public func savedRecipes() throws -> [Recipe] {
        let descriptor = FetchDescriptor<CachedRecipe>(
            predicate: #Predicate { $0.isSaved == true },
            sortBy: [SortDescriptor(\.lastViewedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(Self.toDomain)
    }

    /// Most-recently-viewed recipes for surfacing in Siri / Spotlight (US-10).
    /// Includes both saved and unsaved rows, sorted by `lastViewedAt` (the
    /// same field LRU eviction uses), newest first. Blocklisted rows are
    /// filtered out so we don't suggest a recipe whose detail fetch has
    /// failed.
    public func recentlyViewed(limit: Int = 30) throws -> [Recipe] {
        var descriptor = FetchDescriptor<CachedRecipe>(
            predicate: #Predicate { $0.jsonLDFailedAt == nil },
            sortBy: [SortDescriptor(\.lastViewedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor).map(Self.toDomain)
    }

    /// Fetch a single recipe as a Domain.Recipe by id without bumping
    /// `lastViewedAt`. Used by App Intents entity lookup (US-10) — Siri
    /// surfacing should not pollute the LRU order.
    public func recipeWithoutTouching(id: Int) throws -> Recipe? {
        try fetchRecipe(id: id).map(Self.toDomain)
    }

    // MARK: - Blocklist (AC-1.7)

    /// Mark a recipe as having a failing JSON-LD parse. Subsequent list
    /// queries filter it out.
    public func markJSONLDFailed(id: Int) throws {
        guard let row = try fetchRecipe(id: id) else { return }
        row.jsonLDFailedAt = .now
        try modelContext.save()
    }

    /// Clear all blocklist entries (called from pull-to-refresh).
    public func clearBlocklist() throws {
        let descriptor = FetchDescriptor<CachedRecipe>(
            predicate: #Predicate { $0.jsonLDFailedAt != nil }
        )
        for row in try modelContext.fetch(descriptor) {
            row.jsonLDFailedAt = nil
        }
        try modelContext.save()
    }

    /// List-friendly query: returns RecipeListItems that aren't blocklisted.
    public func listItems(forIDs ids: [Int]) throws -> [RecipeListItem] {
        guard !ids.isEmpty else { return [] }
        let idSet = Set(ids)
        let descriptor = FetchDescriptor<CachedRecipe>(
            predicate: #Predicate { row in
                idSet.contains(row.id) && row.jsonLDFailedAt == nil
            }
        )
        let rows = try modelContext.fetch(descriptor)
        let byID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        // Preserve caller's ordering.
        return ids.compactMap { id in byID[id].map(Self.toListItem) }
    }

    // MARK: - Image cache

    public func cacheImage(url: URL, bytes: Data, pinnedToSavedRecipeID: Int? = nil) throws {
        let urlString = url.absoluteString
        let descriptor = FetchDescriptor<CachedImage>(
            predicate: #Predicate { $0.urlString == urlString }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            existing.bytes = bytes
            existing.lastUsedAt = .now
            if let pin = pinnedToSavedRecipeID {
                existing.pinnedToSavedRecipeID = pin
            }
        } else {
            modelContext.insert(
                CachedImage(
                    urlString: urlString,
                    bytes: bytes,
                    pinnedToSavedRecipeID: pinnedToSavedRecipeID
                )
            )
        }
        try modelContext.save()
        try evictImagesIfNeeded()
    }

    public func image(url: URL) throws -> Data? {
        let urlString = url.absoluteString
        let descriptor = FetchDescriptor<CachedImage>(
            predicate: #Predicate { $0.urlString == urlString }
        )
        guard let row = try modelContext.fetch(descriptor).first else { return nil }
        row.lastUsedAt = .now
        try modelContext.save()
        return row.bytes
    }

    // MARK: - Eviction policies (T-074, T-075)

    /// Trim unsaved CachedRecipes to ``unsavedLRUCap`` by oldest `lastViewedAt`.
    /// Saved recipes are never evicted (NFR-1).
    public func evictIfNeeded() throws {
        let descriptor = FetchDescriptor<CachedRecipe>(
            predicate: #Predicate { $0.isSaved == false },
            sortBy: [SortDescriptor(\.lastViewedAt, order: .forward)]
        )
        let unsaved = try modelContext.fetch(descriptor)
        let overflow = unsaved.count - Self.unsavedLRUCap
        guard overflow > 0 else { return }
        for row in unsaved.prefix(overflow) {
            modelContext.delete(row)
        }
        try modelContext.save()
    }

    /// Trim image rows until total bytes ≤ ``imageBudgetBytes``. Pinned rows
    /// (saved-recipe images) are excluded from eviction (NFR-2).
    public func evictImagesIfNeeded() throws {
        let descriptor = FetchDescriptor<CachedImage>(
            sortBy: [SortDescriptor(\.lastUsedAt, order: .forward)]
        )
        let all = try modelContext.fetch(descriptor)
        var total = all.reduce(0) { $0 + $1.bytes.count }
        guard total > Self.imageBudgetBytes else { return }
        for row in all where row.pinnedToSavedRecipeID == nil {
            let size = row.bytes.count
            modelContext.delete(row)
            total -= size
            if total <= Self.imageBudgetBytes { break }
        }
        try modelContext.save()
    }

    // MARK: - Helpers

    private func fetchRecipe(id: Int) throws -> CachedRecipe? {
        let descriptor = FetchDescriptor<CachedRecipe>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    private static func secondsOf(_ duration: Duration) -> Int {
        Int(duration.components.seconds)
    }

    private static func toListItem(_ row: CachedRecipe) -> RecipeListItem {
        RecipeListItem(
            id: row.id,
            title: row.title,
            excerpt: row.excerptText,
            heroImage: row.heroImageURLString.flatMap { URL(string: $0) },
            publishedAt: row.publishedAt,
            totalTimeDisplay: row.totalSeconds.map(formatTime),
            canonicalURL: row.canonicalURLString.isEmpty ? nil : URL(string: row.canonicalURLString)
        )
    }

    private static func toDomain(_ row: CachedRecipe) -> Recipe {
        let canonical = URL(string: row.canonicalURLString) ?? URL(filePath: "/dev/null")
        let ingredients =
            (row.ingredientsJSON.flatMap {
                try? JSONDecoder().decode([RecipeIngredient].self, from: $0)
            }) ?? []
        let instructions =
            (row.instructionsJSON.flatMap {
                try? JSONDecoder().decode([RecipeInstruction].self, from: $0)
            }) ?? []
        let nutrition = row.nutritionJSON.flatMap {
            try? JSONDecoder().decode(RecipeNutrition.self, from: $0)
        }
        let video = row.videoJSON.flatMap {
            try? JSONDecoder().decode(RecipeVideo.self, from: $0)
        }
        return Recipe(
            id: row.id,
            slug: row.slug,
            title: row.title,
            excerpt: row.excerptText,
            canonicalURL: canonical,
            heroImage: row.heroImageURLString.flatMap { URL(string: $0) },
            heroImageLargeURL: row.heroImageLargeURLString.flatMap { URL(string: $0) },
            categoryIDs: row.categoryIDs,
            publishedAt: row.publishedAt,
            ingredients: ingredients,
            instructions: instructions,
            prepTime: row.prepSeconds.map { .seconds($0) },
            cookTime: row.cookSeconds.map { .seconds($0) },
            totalTime: row.totalSeconds.map { .seconds($0) },
            servings: row.servings,
            nutrition: nutrition,
            video: video
        )
    }
}

// MARK: - Container construction

extension RecipeStore {

    /// Create the on-disk container for production use. Pinned to the
    /// latest schema (`SchemaV3`) — older on-disk stores get migrated via
    /// `MigrationPlan` at open.
    public static func productionContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(SchemaV3.models),
            migrationPlan: MigrationPlan.self,
            configurations: ModelConfiguration()
        )
    }

    /// Create an in-memory container for tests. Uses the current schema so
    /// fixture data exercises the same models the app ships with.
    public static func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(SchemaV3.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// Create an in-memory container at the legacy V1 schema. Used only by
    /// the V1→V2 migration test to prove a pre-US-12 store opens cleanly
    /// under V2. Production code never calls this.
    public static func inMemoryContainerV1() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(SchemaV1.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// Create an in-memory container at the V2 schema. Used only by the
    /// V2→V3 migration test to prove a pre-US-13/14 store opens cleanly
    /// under V3. Production code never calls this.
    public static func inMemoryContainerV2() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(SchemaV2.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}

private func formatTime(seconds: Int) -> String {
    let minutes = seconds / 60
    if minutes < 60 { return "\(minutes) min" }
    let hours = minutes / 60
    let remainder = minutes % 60
    if remainder == 0 { return "\(hours) hr" }
    return "\(hours)h \(remainder)m"
}
