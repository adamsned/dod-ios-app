import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// DUT-1340 — the long-press bookmark "Add to Collection" commit logic. Locks
/// the save-first semantics: membership is a subset of the saved set, so adding
/// an unsaved recipe to a collection must save it first (else it would be
/// pruned), while an empty selection must never force-save. Uses the in-memory
/// `FakeRecipeDetailDependencies` collections modeling.
@MainActor
@Suite("RecipeDetailViewModel collections (DUT-1340)")
struct RecipeDetailCollectionsTests {

    @Test func unsavedNonEmptySelectionSavesAndSetsMembership() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.cachedRecipes[1340] = RecipeDetailTestFixtures.makeRecipe(
            id: 1340,
            withDetail: true
        )
        let collection = try await dependencies.createCollection(name: "Camping")
        let viewModel = makeViewModel(dependencies: dependencies, listItemID: 1340)
        await viewModel.onAppear()
        #expect(viewModel.isSaved == false)

        await viewModel.commitCollections([collection.id])

        // Save-first: the unsaved recipe is saved so it survives in the collection.
        #expect(viewModel.isSaved == true)
        #expect(dependencies.savedIDs.contains(1340))
        #expect(dependencies.membershipByRecipe[1340] == [collection.id])
    }

    @Test func unsavedEmptySelectionDoesNotForceSave() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.cachedRecipes[1341] = RecipeDetailTestFixtures.makeRecipe(
            id: 1341,
            withDetail: true
        )
        let viewModel = makeViewModel(dependencies: dependencies, listItemID: 1341)
        await viewModel.onAppear()
        #expect(viewModel.isSaved == false)

        await viewModel.commitCollections([])

        // Empty selection on an unsaved recipe is a no-op — never force-saves.
        #expect(viewModel.isSaved == false)
        #expect(dependencies.savedIDs.contains(1341) == false)
        #expect(dependencies.membershipByRecipe[1341]?.isEmpty == true)
    }

    @Test func savedRecipeSelectionSetsMembershipStaysSaved() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.savedIDs.insert(1342)
        dependencies.cachedRecipes[1342] = RecipeDetailTestFixtures.makeRecipe(
            id: 1342,
            withDetail: true
        )
        let collection = try await dependencies.createCollection(name: "Weeknight")
        let viewModel = makeViewModel(dependencies: dependencies, listItemID: 1342)
        await viewModel.onAppear()
        #expect(viewModel.isSaved == true)

        await viewModel.commitCollections([collection.id])

        #expect(viewModel.isSaved == true)
        #expect(dependencies.membershipByRecipe[1342] == [collection.id])
    }

    @Test func savedRecipeEmptySelectionRemovesFromAllStaysSaved() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.savedIDs.insert(1343)
        let collection = try await dependencies.createCollection(name: "Thanksgiving")
        dependencies.membershipByRecipe[1343] = [collection.id]
        dependencies.cachedRecipes[1343] = RecipeDetailTestFixtures.makeRecipe(
            id: 1343,
            withDetail: true
        )
        let viewModel = makeViewModel(dependencies: dependencies, listItemID: 1343)
        await viewModel.onAppear()
        #expect(viewModel.isSaved == true)

        await viewModel.commitCollections([])

        // Removing from every collection leaves the recipe saved (a collection is
        // only a grouping) and empties its membership.
        #expect(viewModel.isSaved == true)
        #expect(dependencies.membershipByRecipe[1343]?.isEmpty == true)
    }

    @Test func loadCollectionsForPickerSeedsCollectionsAndSelection() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.cachedRecipes[1344] = RecipeDetailTestFixtures.makeRecipe(
            id: 1344,
            withDetail: true
        )
        let collection = try await dependencies.createCollection(name: "Camping")
        _ = try await dependencies.createCollection(name: "Quick")
        dependencies.membershipByRecipe[1344] = [collection.id]
        let viewModel = makeViewModel(dependencies: dependencies, listItemID: 1344)
        await viewModel.onAppear()

        await viewModel.loadCollectionsForPicker()

        #expect(viewModel.pickerCollections.count == 2)
        #expect(viewModel.pickerInitialSelection == [collection.id])
    }

    private func makeViewModel(
        dependencies: RecipeDetailDependencies,
        listItemID: Int
    ) -> RecipeDetailViewModel {
        RecipeDetailViewModel(
            listItem: RecipeDetailTestFixtures.makeListItem(id: listItemID),
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/\(listItemID)/")
                ?? URL(filePath: "/"),
            dependencies: dependencies
        )
    }
}
