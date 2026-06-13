import DODDomain
import DODNetworking
import DODPersistence
import Foundation

public protocol CategoriesDependencies: Sendable {
    func fetchCategories() async throws -> [DODDomain.Category]
    func fetchPosts(categoryID: Int, page: Int) async throws -> [RecipeListItem]
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

    public func fetchPosts(categoryID: Int, page: Int) async throws -> [RecipeListItem] {
        try await client.posts(categoryID: categoryID, page: page)
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
