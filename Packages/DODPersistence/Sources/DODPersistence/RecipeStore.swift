import DODDomain
import DODSupport
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

    /// DUT-242: flips true after the first ``backfillImageByteCountsIfNeeded()``
    /// so the one-time `byteCount` backfill faults image blobs once per launch.
    var didBackfillImageByteCounts = false

    #if DEBUG
    /// DUT-473 test seam: when set, ``logCook`` throws this instead of saving so
    /// a test can drive the failed-save rollback. Per-actor (not a global
    /// static) so parallel suites can't observe each other's failpoint.
    var cookLogSaveFailpointError: Error?

    /// DUT-593 test seam: when set, ``logCook`` throws this at the ±3s dedup
    /// fetch (an on-device fetch failure isn't hermetically reproducible). Proves
    /// the fetch now uses `try` — a fetch error propagates rather than silently
    /// skipping the dedup and inserting a duplicate cook. Per-actor, like above.
    var cookLogDedupFetchFailpointError: Error?
    #endif

    /// DUT-302: flips true once `AppDependencies.bootstrap` confirms the one-time
    /// SyncedSaved backfill completed. Until then, ``mergeDetail`` must NOT clear
    /// a legacy local `isSaved` pin — the backfill (selecting `isSaved == true`)
    /// hasn't migrated it to the synced store yet, so clearing it would
    /// permanently lose an upgrader's save. DUT-493: seeded from the durable
    /// ``backfillDidComplete(in:)`` flag (skips the DUT-470 launch window).
    public internal(set) var didBackfillSyncedSaved = RecipeStore.backfillDidComplete()

    /// DUT-257 — test-only spy: ``evictIfNeeded()`` invocation count (proves a
    /// bulk ``cache(listItems:)`` evicts once, not per item). Not for production.
    var evictIfNeededCallCount = 0

    // MARK: - List item cache

    /// Insert-or-update a list item. Sets `lastViewedAt` so LRU sees it as fresh.
    public func cache(listItem: RecipeListItem) throws {
        try upsert(listItem: listItem)
        try modelContext.save()
        try evictIfNeeded()
    }

    /// DUT-257 — pure insert/update body (no per-call save/evict) shared by both
    /// cache entry points, so the bulk path can save + evict once. Non-private so
    /// the bulk `cache(listItems:)` path in `RecipeStore+ListCache.swift` reuses it.
    func upsert(listItem: RecipeListItem) throws {
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
            // T-530 / CL-53 / REG-17: propagate WP categories from the
            // REST payload so the Search-tab category chip can filter
            // fresh REST hits without waiting for the recipe-detail JSON-LD
            // merge. Same don't-clobber-with-empty guard `canonicalURL`
            // above uses — a non-empty REST categories array wins; nil or
            // empty leaves the existing populated `categoryIDs` alone (so
            // a re-fetch can't wipe data that `mergeDetail(_:)` already
            // wrote from the JSON-LD parse).
            if let categoryIDs = listItem.categoryIDs, !categoryIDs.isEmpty {
                existing.categoryIDs = categoryIDs
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
                    // T-530 / CL-53 / REG-17: REST-supplied categories
                    // hydrate the row on insert so the category filter
                    // works for first-time REST hits the user hasn't
                    // opened yet. nil-on-the-wire falls back to the
                    // initializer's default `[]`.
                    categoryIDs: listItem.categoryIDs ?? [],
                    publishedAt: listItem.publishedAt,
                    lastViewedAt: .now
                )
            )
        }
    }

    // DUT-257 bulk `cache(listItems:)` (+ DUT-556 intra-batch dedup) lives in
    // `RecipeStore+ListCache.swift` to keep this file under the 400-line
    // file_length cap.

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
        // DUT-592: don't clobber cached ingredients/instructions with `[]` on a
        // partial recipe-kind re-parse (see `applyIngredientsAndInstructions`).
        try applyIngredientsAndInstructions(from: recipe, to: target)
        // DUT-399: copy parsed detail fields without clobbering cached values with
        // nil (see `applyParsedDetailFields`).
        applyParsedDetailFields(from: recipe, to: target)
        target.lastViewedAt = .now

        // US-37 / CL-63 / T-640: persist article body; kind drives the
        // jsonLDFailedAt discriminator (CL-63 decision 7).
        target.articleBodyHTML = recipe.articleBodyHTML
        switch recipe.kind {
        case .recipe:
            target.jsonLDParsedAt = .now
            target.jsonLDFailedAt = nil
        case .article:
            target.jsonLDFailedAt = .now
        }

        // DUT-35 / DUT-302: reconcile the local pin with the synced source of
        // truth so a recipe saved on another device is pinned (LRU/widget) once
        // cached here. `toggleSaved` writes `SyncedSavedRecipe` synchronously, so
        // a just-saved recipe's pin is preserved. DUT-302: until the one-time
        // backfill has migrated the legacy pins (`didBackfillSyncedSaved`),
        // reconcile only UPWARD — a synced row pins it, but a MISSING synced row
        // must not CLEAR a still-true legacy pin (the backfill selects
        // `isSaved == true`; clearing it first means the backfill never migrates
        // it → the upgrader's save is permanently lost).
        if try fetchSyncedSaved(id: recipe.id) != nil {
            target.isSaved = true
            // DUT-413: pin the hero too — `isSaved` alone leaves the just-cached
            // bytes evictable (`toggleSaved` pins via `pinHeroImage`; missed here).
            try pinHeroImage(heroURLString: target.heroImageURLString, toRecipeID: recipe.id)
        } else if didBackfillSyncedSaved {
            target.isSaved = false
            // DUT-512: mirror the explicit-unsave teardown (drop download + pins).
            try tearDownUnsavedPins(target)
        }

        // US-12 / AC-12.1: keep the local ingredient index in sync.
        // Article rows have empty `ingredients`, so this clears any
        // stale entries from a prior recipe-kind merge.
        try replaceIngredientIndexRows(forRecipeID: recipe.id, with: recipe.ingredients)

        try modelContext.save()
    }

    /// Read a recipe back, stitched into a Domain.Recipe.
    public func recipe(id: Int) throws -> Recipe? {
        guard let row = try fetchRecipe(id: id) else { return nil }
        return Self.toDomain(row)
    }

    // MARK: - Save / unsave (AC-5.1)

    // `isSaved(id:)` lives in `RecipeStore+SyncedSaved.swift` (file_length cap).

    // US-5 / DUT-35 — `toggleSaved(id:)` + `markSaved(id:)` (incl. the DUT-215
    // unsave teardown) live in `RecipeStore+Saved.swift` (file_length cap).

    // `savedRecipes()` + `savedRecipesWithSavedAt()` (DUT-35 / DUT-513) live in
    // `RecipeStore+SyncedSaved.swift` (file_length cap).

    // MARK: - Explicit download (US-35 / AC-35.2 / AC-35.5)

    /// Mark the recipe explicitly downloaded for offline use. Sets
    /// ``CachedRecipe/downloadedAt`` on the first call; a re-tap preserves the
    /// timestamp and is a no-op (AC-35.4). Returns `true` on the transition,
    /// `false` if already downloaded (caller branches the snackbar copy).
    @discardableResult
    public func markDownloaded(id: Int) throws -> Bool {
        guard let row = try fetchRecipe(id: id) else { return false }
        if row.downloadedAt != nil {
            return false
        }
        row.downloadedAt = .now
        try modelContext.save()
        return true
    }

    /// True when the recipe was explicitly downloaded (US-35). T-761 / CL-158
    /// decoupled this from ``isSaved(id:)`` — only a Download tap (its
    /// ``markDownloaded(id:)``) sets `downloadedAt`; saving alone does not.
    public func isDownloaded(id: Int) throws -> Bool {
        try fetchRecipe(id: id)?.downloadedAt != nil
    }

    /// Most-recently-viewed recipes for surfacing in Siri / Spotlight (US-10).
    /// Includes both saved and unsaved rows, sorted by `lastViewedAt`
    /// (the same field LRU eviction uses), newest first.
    ///
    /// US-37 / CL-63 / AC-37.4 (T-640): articles are no longer filtered
    /// out — they're included alongside recipes and the App Intents entry
    /// branches on `Recipe.kind` for the detail screen.
    public func recentlyViewed(limit: Int = 30) throws -> [Recipe] {
        var descriptor = FetchDescriptor<CachedRecipe>(
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

    /// Every cached recipe's title — the source pool for Search's "did you
    /// mean?" suggestion engine (T-649 / CL-127), which tokenizes them to find
    /// the closest-Levenshtein neighbor for a sparse query. Empty on a cold
    /// cache (caller short-circuits to a `nil` suggestion).
    public func cachedRecipeTitles() throws -> [String] {
        let descriptor = FetchDescriptor<CachedRecipe>()
        return try modelContext.fetch(descriptor).map(\.title)
    }

    /// List-friendly query: returns RecipeListItems for the requested ids.
    ///
    /// US-37 / CL-63 / AC-37.4 (T-640): articles are no longer filtered
    /// out — they're returned alongside recipes in the same row format.
    public func listItems(forIDs ids: [Int]) throws -> [RecipeListItem] {
        guard !ids.isEmpty else { return [] }
        let idSet = Set(ids)
        let descriptor = FetchDescriptor<CachedRecipe>(
            predicate: #Predicate { row in
                idSet.contains(row.id)
            }
        )
        let rows = try modelContext.fetch(descriptor)
        let byID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        // Preserve caller's ordering.
        return ids.compactMap { id in byID[id].map(Self.toListItem) }
    }

    // MARK: - Eviction policies (T-074)
    //
    // `evictIfNeeded()` + its DUT-591 dependent-row cascade live in
    // `RecipeStore+Eviction.swift`; image cache + image-eviction live in
    // `RecipeStore+ImageCache.swift` — both extracted to keep this actor body
    // under the `type_body_length` cap.

    // MARK: - Helpers

    // Internal (not private) so the `+Saved`/`+Download`/… extensions in sibling
    // files can fetch a row by id (the codebase splits RecipeStore aggressively).
    func fetchRecipe(id: Int) throws -> CachedRecipe? {
        let descriptor = FetchDescriptor<CachedRecipe>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    static func secondsOf(_ duration: Duration) -> Int {
        Int(duration.components.seconds)
    }

    private static func toListItem(_ row: CachedRecipe) -> RecipeListItem {
        RecipeListItem(
            id: row.id,
            title: row.title,
            excerpt: row.excerptText,
            heroImage: row.heroImageURLString.flatMap { URL(string: $0) },
            publishedAt: row.publishedAt,
            totalTimeDisplay: row.totalSeconds.flatMap(formatTime),
            canonicalURL: row.canonicalURLString.isEmpty ? nil : URL(string: row.canonicalURLString)
        )
    }

    // Non-private (DUT-513): `savedRecipesWithSavedAt()` in
    // `RecipeStore+SyncedSaved.swift` maps provisional `CachedRecipe` pins here.
    static func toDomain(_ row: CachedRecipe) -> Recipe {
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
        // US-37 / CL-63 / AC-37.4 (T-640): reconstruct kind from row
        // signals. Non-nil `jsonLDFailedAt` + non-empty body ⇒ article.
        // Pre-T-640 blocklist rows (no body) surface as recipes with
        // empty content so `hasDetail` triggers a fresh fetch.
        let kind: PostKind =
            (row.jsonLDFailedAt != nil && !(row.articleBodyHTML ?? "").isEmpty)
            ? .article : .recipe
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
            video: video,
            kind: kind,
            articleBodyHTML: row.articleBodyHTML,
            recipeCategory: row.recipeCategory,
            recipeCuisine: row.recipeCuisine,
            suitableForDiet: row.suitableForDiet,
            author: row.author
        )
    }
}
// `formatTime(seconds:)` moved to `TimeFormatting.swift` for the 400-line cap.
