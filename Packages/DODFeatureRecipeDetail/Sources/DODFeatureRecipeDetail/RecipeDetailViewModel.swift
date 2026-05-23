import DODAnalytics
import DODDomain
import DODSupport
import Foundation
import Observation

/// Spec trace: AC-4.* (recipe detail behavior), AC-4.11 (failure path),
/// AC-5.1 (save toggle + undo), AC-5.4 (offline), AC-6.* (share).
@Observable
@MainActor
public final class RecipeDetailViewModel {

    public enum LoadState: Equatable {
        case loadingDetail
        case ready
        case unavailable  // AC-4.11
    }

    public let listItem: RecipeListItem
    public let canonicalURL: URL
    public private(set) var recipe: Recipe?
    public private(set) var related: [RecipeListItem] = []
    public private(set) var loadState: LoadState = .loadingDetail
    public private(set) var isSaved: Bool = false
    public private(set) var checkedIngredientIDs: Set<UUID> = []
    public private(set) var snackbarMessage: String?

    private let dependencies: RecipeDetailDependencies

    public init(
        listItem: RecipeListItem,
        canonicalURL: URL,
        dependencies: RecipeDetailDependencies
    ) {
        self.listItem = listItem
        self.canonicalURL = canonicalURL
        self.dependencies = dependencies
    }

    public var isOffline: Bool {
        get async { await !dependencies.isOnline() }
    }

    public func onAppear() async {
        // Telemetry per AC and constitution §9.
        await dependencies.sendTelemetry(.recipeView(recipeID: listItem.id))
        isSaved = (try? await dependencies.isSaved(id: listItem.id)) ?? false
        // Step 1: hydrate from cache if present (fast path).
        if let cached = try? await dependencies.cachedRecipe(id: listItem.id), cached.hasDetail {
            recipe = cached
            loadState = .ready
            await loadRelated(forCategoryID: cached.categoryIDs.first)
            return
        }
        // Step 2: try fetch + parse.
        await fetchAndParse()
    }

    public func toggleIngredient(_ id: UUID) {
        if checkedIngredientIDs.contains(id) {
            checkedIngredientIDs.remove(id)
        } else {
            checkedIngredientIDs.insert(id)
        }
    }

    public func toggleSaved() async {
        do {
            let nowSaved = try await dependencies.toggleSaved(id: listItem.id)
            isSaved = nowSaved
            if nowSaved {
                await dependencies.sendTelemetry(.recipeSaved(recipeID: listItem.id))
                snackbarMessage = "Saved for offline."
            } else {
                await dependencies.sendTelemetry(.recipeUnsaved(recipeID: listItem.id))
                snackbarMessage = "Removed from saved."
            }
        } catch {
            DODLog.persistence.error("toggle save failed: \(String(describing: error))")
        }
    }

    public func didShare() async {
        await dependencies.sendTelemetry(.recipeShared(recipeID: listItem.id))
    }

    public func dismissSnackbar() {
        snackbarMessage = nil
    }

    // MARK: - Internal

    private func fetchAndParse() async {
        do {
            let html = try await dependencies.fetchHTML(for: canonicalURL)
            let parsed = try dependencies.parseJSONLD(
                html: html,
                merging: listItem,
                canonicalURL: canonicalURL
            )
            try await dependencies.mergeDetail(parsed)
            recipe = parsed
            loadState = .ready
            await loadRelated(forCategoryID: parsed.categoryIDs.first)
        } catch {
            DODLog.network.error("recipe detail fetch failed: \(String(describing: error))")
            try? await dependencies.markJSONLDFailed(id: listItem.id)
            loadState = .unavailable
            snackbarMessage = "Recipe unavailable."
        }
    }

    private func loadRelated(forCategoryID categoryID: Int?) async {
        guard let categoryID, await dependencies.isOnline() else {
            related = []
            return
        }
        let fetched = try? await dependencies.relatedRecipes(forCategoryID: categoryID)
        related = (fetched ?? []).filter { $0.id != listItem.id }
    }
}
