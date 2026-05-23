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

    private let dependencies: CategoriesDependencies
    private var currentPage: Int = 0
    private var reachedEnd: Bool = false

    public init(category: DODDomain.Category, dependencies: CategoriesDependencies) {
        self.category = category
        self.dependencies = dependencies
    }

    public func onAppear() async {
        guard items.isEmpty else { return }
        await load(page: 1)
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
            let fetched = try await dependencies.fetchPosts(categoryID: category.id, page: page)
            try await dependencies.cache(listItems: fetched)
            if append {
                let combinedIDs = (items.map(\.id) + fetched.map(\.id)).reduce(into: [Int]()) { acc, id in
                    if !acc.contains(id) { acc.append(id) }
                }
                items = try await dependencies.cachedListItems(forIDs: combinedIDs)
            } else {
                items = try await dependencies.cachedListItems(forIDs: fetched.map(\.id))
            }
            currentPage = page
            if fetched.count < 20 { reachedEnd = true }
            loadState = items.isEmpty ? .empty : .loaded
        } catch {
            DODLog.network.error("category load failed: \(String(describing: error))")
            loadState = .error
        }
    }
}
