import DODDomain
import DODNetworking
import DODPersistence
import Foundation

public protocol CategoriesDependencies: Sendable {
    func fetchCategories() async throws -> [DODDomain.Category]
    /// DUT-265: returns the page's items + WP's total page count
    /// (`X-WP-TotalPages`) so the view model stops at the real last page instead
    /// of guessing from a short page (mirrors the DUT-237 feed fix).
    func fetchPosts(
        categoryID: Int,
        page: Int
    ) async throws -> (items: [RecipeListItem], totalPages: Int)
    func cache(listItems: [RecipeListItem]) async throws
    func cachedListItems(forIDs ids: [Int]) async throws -> [RecipeListItem]
    /// T-765 / CL-162 (DUT-71) — saved recipe id set for the card long-press
    /// Save/Unsave label. Default `[]` keeps existing fake conformers compiling.
    func savedRecipeIDs() async throws -> Set<Int>
}

extension CategoriesDependencies {
    public func savedRecipeIDs() async throws -> Set<Int> { [] }
}

public struct LiveCategoriesDependencies: CategoriesDependencies {
    let client: WPRestClient
    let store: RecipeStore

    public init(client: WPRestClient, store: RecipeStore) {
        self.client = client
        self.store = store
    }

    public func fetchCategories() async throws -> [DODDomain.Category] {
        try await client.categories()
    }

    public func fetchPosts(
        categoryID: Int,
        page: Int
    ) async throws -> (items: [RecipeListItem], totalPages: Int) {
        try await client.postsPage(categoryID: categoryID, page: page)
    }

    public func cache(listItems: [RecipeListItem]) async throws {
        try await store.cache(listItems: listItems)
    }

    public func cachedListItems(forIDs ids: [Int]) async throws -> [RecipeListItem] {
        try await store.listItems(forIDs: ids)
    }

    public func savedRecipeIDs() async throws -> Set<Int> {
        try await store.savedRecipeIDs()
    }
}
