import DODDomain
import DODSupport
import Foundation
import Observation

/// Recipes in a single category, paged.
/// Spec trace: AC-2.3, AC-2.5.
@Observable
@MainActor
public final class CategoryRecipesViewModel {

    public enum LoadState: Equatable {
        case idle, loadingInitial, loaded, loadingMore, empty, error
    }

    public let category: DODDomain.Category
    public private(set) var items: [RecipeListItem] = []
    public private(set) var loadState: LoadState = .idle
    /// T-765 / CL-162 (DUT-71) — saved recipe ids for the card long-press
    /// Save/Unsave label (hydrated on appear; optimistic flip on toggle).
    public private(set) var savedRecipeIDs: Set<Int> = []

    private let dependencies: CategoriesDependencies
    private var currentPage: Int = 0
    private var reachedEnd: Bool = false

    public init(category: DODDomain.Category, dependencies: CategoriesDependencies) {
        self.category = category
        self.dependencies = dependencies
    }

    public func onAppear() async {
        // Refresh first (ungated) so a save made on another surface reflects
        // in the card long-press menu even when items are already loaded.
        await refreshSavedRecipeIDs()
        guard items.isEmpty else { return }
        await load(page: 1)
    }

    /// T-765 / CL-162 (DUT-71) — reload the saved-id set from the store (cheap
    /// id projection); called on every appear so a save made on another surface
    /// reflects in the card long-press menu's Save/Unsave label.
    public func refreshSavedRecipeIDs() async {
        if let ids = try? await dependencies.savedRecipeIDs() {
            savedRecipeIDs = ids
        }
    }

    /// Optimistically flip a recipe's saved membership on a long-press toggle
    /// so the menu label is correct on re-open; the next refresh reconciles.
    public func applyOptimisticSaveToggle(id: Int) {
        if savedRecipeIDs.contains(id) {
            savedRecipeIDs.remove(id)
        } else {
            savedRecipeIDs.insert(id)
        }
    }

    public func retry() async {
        await load(page: 1)
    }

    public func loadMoreIfNeeded(currentItem: RecipeListItem) async {
        guard !reachedEnd,
            loadState == .loaded,
            items.suffix(3).contains(where: { $0.id == currentItem.id })
        else { return }
        await load(page: currentPage + 1, append: true)
    }

    private func load(page: Int, append: Bool = false) async {
        loadState = append ? .loadingMore : .loadingInitial
        do {
            let result = try await dependencies.fetchPosts(categoryID: category.id, page: page)
            try await dependencies.cache(listItems: result.items)
            if append {
                let combinedIDs = (items.map(\.id) + result.items.map(\.id))
                    .reduce(into: [Int]()) { acc, id in
                        if !acc.contains(id) { acc.append(id) }
                    }
                items = try await dependencies.cachedListItems(forIDs: combinedIDs)
            } else {
                items = try await dependencies.cachedListItems(forIDs: result.items.map(\.id))
            }
            currentPage = page
            // DUT-265: stop at the real last page (X-WP-TotalPages), not at a
            // short page — mirrors the DUT-237 feed fix.
            reachedEnd = currentPage >= result.totalPages
            loadState = items.isEmpty ? .empty : .loaded
        } catch {
            DODLog.network.error("category load failed: \(String(describing: error))")
            loadState = .error
        }
    }
}
