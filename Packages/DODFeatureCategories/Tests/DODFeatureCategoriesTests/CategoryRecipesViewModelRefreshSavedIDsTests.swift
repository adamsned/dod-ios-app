import DODDomain
import Foundation
import Testing

@testable import DODFeatureCategories

/// Tests for `CategoryRecipesViewModel.refreshSavedRecipeIDs()` method in isolation.
/// Covers: direct success, silent failure (the untested gap), and empty-set success.
@MainActor
@Suite("CategoryRecipesViewModel.refreshSavedRecipeIDs() (T-765)") struct RefreshSavedIDsTests {

    @Test func directSuccessUpdatesSavedRecipeIDs() async {
        // Test that calling `refreshSavedRecipeIDs()` directly (not through
        // `onAppear`/`refresh`) updates `savedRecipeIDs` when the dependency
        // succeeds with a populated set.
        let dependencies = ThrowingFakeCategoriesDependencies()
        dependencies.savedIDsToReturn = [1, 2, 3]
        let category = DODDomain.Category(id: 1, name: "Test", slug: "test", count: 0)
        let viewModel = CategoryRecipesViewModel(category: category, dependencies: dependencies)

        // Before the call, savedRecipeIDs starts empty.
        #expect(viewModel.savedRecipeIDs.isEmpty)

        // Call refreshSavedRecipeIDs directly (not through onAppear/refresh).
        await viewModel.refreshSavedRecipeIDs()

        // Property is updated to the exact set the dependency returned.
        #expect(viewModel.savedRecipeIDs == [1, 2, 3])
    }

    @Test func silentFailureLeavesSavedRecipeIDsUnchanged() async {
        // Test the untested failure branch: when the dependency throws,
        // `refreshSavedRecipeIDs()` silently swallows the error and leaves
        // `savedRecipeIDs` COMPLETELY UNCHANGED (not reset to empty, not partially
        // updated). This is the key behavior that was never covered.
        let dependencies = ThrowingFakeCategoriesDependencies()
        // Seed the initial state with a non-empty set.
        dependencies.savedIDsToReturn = [10, 20, 30]
        let category = DODDomain.Category(id: 1, name: "Test", slug: "test", count: 0)
        let viewModel = CategoryRecipesViewModel(category: category, dependencies: dependencies)

        // First call: succeed to populate the initial set.
        await viewModel.refreshSavedRecipeIDs()
        #expect(viewModel.savedRecipeIDs == [10, 20, 30])

        // Arm the dependency to throw on the next call.
        dependencies.shouldThrow = true

        // Second call: dependency throws, but the property must not change.
        await viewModel.refreshSavedRecipeIDs()

        // The saved IDs remain EXACTLY as they were before the failed call.
        #expect(viewModel.savedRecipeIDs == [10, 20, 30])
    }

    @Test func emptySetSuccessTransitionsToEmptySet() async {
        // Test that when the dependency succeeds but returns an empty set,
        // `savedRecipeIDs` is updated to empty. This distinguishes between
        // "succeeded with nothing" and "failed and kept old value".
        let dependencies = ThrowingFakeCategoriesDependencies()
        // Seed with a populated initial set.
        dependencies.savedIDsToReturn = [5, 15, 25]
        let category = DODDomain.Category(id: 1, name: "Test", slug: "test", count: 0)
        let viewModel = CategoryRecipesViewModel(category: category, dependencies: dependencies)

        // First call: populate the set.
        await viewModel.refreshSavedRecipeIDs()
        #expect(viewModel.savedRecipeIDs == [5, 15, 25])

        // Change the dependency to return an empty set.
        dependencies.savedIDsToReturn = []

        // Second call: dependency succeeds with empty set.
        await viewModel.refreshSavedRecipeIDs()

        // The property is updated to empty (not left as [5, 15, 25]).
        #expect(viewModel.savedRecipeIDs.isEmpty)
    }

    @Test func silentFailureFromEmptyInitialStateLeavesSavedRecipeIDsEmpty() async {
        // Edge case: even if the initial state is empty and the dependency throws,
        // the property must stay empty (not attempt a partial update or reset).
        // This validates the "unchanged" contract even from the default empty state.
        let dependencies = ThrowingFakeCategoriesDependencies()
        dependencies.shouldThrow = true
        let category = DODDomain.Category(id: 1, name: "Test", slug: "test", count: 0)
        let viewModel = CategoryRecipesViewModel(category: category, dependencies: dependencies)

        // Initial state is empty by default.
        #expect(viewModel.savedRecipeIDs.isEmpty)

        // Call refreshSavedRecipeIDs with dependency throwing.
        await viewModel.refreshSavedRecipeIDs()

        // Still empty (the no-op contract is maintained).
        #expect(viewModel.savedRecipeIDs.isEmpty)
    }
}

/// Test double for `CategoriesDependencies` that can optionally throw on `savedRecipeIDs()`.
/// Used exclusively for `refreshSavedRecipeIDs` failure-path testing (unlike `FakeCategoriesDependencies`
/// which always succeeds). Minimal conformance — stubs other methods to guard against accidental calls.
final class ThrowingFakeCategoriesDependencies: CategoriesDependencies, @unchecked Sendable {
    enum TestError: Error {
        case intentionalThrow
    }

    var shouldThrow = false
    var savedIDsToReturn: Set<Int> = []

    func fetchCategories() async throws -> [DODDomain.Category] {
        []
    }

    func fetchPosts(
        categoryID: Int,
        page: Int
    ) async throws -> (items: [RecipeListItem], totalPages: Int) {
        ([], 1)
    }

    func cache(listItems: [RecipeListItem]) async throws {}

    func cachedListItems(forIDs ids: [Int]) async throws -> [RecipeListItem] {
        []
    }

    func savedRecipeIDs() async throws -> Set<Int> {
        if shouldThrow {
            throw TestError.intentionalThrow
        }
        return savedIDsToReturn
    }
}
