import DODDomain
import Foundation
import Testing

@testable import DODFeatureSaved

/// DUT-105 — the collections half of ``SavedViewModel``: loading the shelf,
/// the create/rename/delete CRUD, the shelf filter (``displayedRecipes``), and
/// membership for the "Add to Collection" sheet.
@MainActor
@Suite("SavedViewModel collections (DUT-105)") struct SavedViewModelCollectionsTests {

    private func makeRecipe(id: Int) -> Recipe {
        Recipe(
            id: id,
            slug: "s\(id)",
            title: "Title \(id)",
            excerpt: "Excerpt",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/\(id)/") ?? URL(filePath: "/"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            ingredients: [.init(text: "salt")],
            instructions: [.init(step: 1, text: "Mix.")]
        )
    }

    @Test func refreshLoadsCollections() async {
        let dependencies = FakeSavedDependencies()
        dependencies.recipes = [makeRecipe(id: 1)]
        dependencies.storedCollections = [
            RecipeCollection(id: UUID(), name: "Camping", sortOrder: 0, createdAt: .now, recipeIDs: [])
        ]
        let viewModel = SavedViewModel(dependencies: dependencies)
        await viewModel.refresh()
        #expect(viewModel.collections.map(\.name) == ["Camping"])
    }

    @Test func createSelectsTheNewCollection() async {
        let dependencies = FakeSavedDependencies()
        dependencies.recipes = [makeRecipe(id: 1)]
        let viewModel = SavedViewModel(dependencies: dependencies)
        await viewModel.refresh()

        await viewModel.createCollection(name: "Breads")
        #expect(viewModel.collections.map(\.name) == ["Breads"])
        #expect(viewModel.selectedCollection?.name == "Breads")
    }

    @Test func addCollectionDoesNotChangeTheShelfFilter() async {
        let dependencies = FakeSavedDependencies()
        dependencies.recipes = [makeRecipe(id: 1)]
        let viewModel = SavedViewModel(dependencies: dependencies)
        await viewModel.refresh()

        // The sheet's inline create must not yank the shelf selection.
        _ = await viewModel.addCollection(name: "Weeknight")
        #expect(viewModel.selectedCollectionID == nil)
        #expect(viewModel.collections.map(\.name) == ["Weeknight"])
    }

    @Test func displayedRecipesFiltersToSelectedCollection() async {
        let dependencies = FakeSavedDependencies()
        dependencies.recipes = [makeRecipe(id: 1), makeRecipe(id: 2), makeRecipe(id: 3)]
        let viewModel = SavedViewModel(dependencies: dependencies)
        await viewModel.refresh()

        await viewModel.addCollection(name: "Dinner")
        let dinner = viewModel.collections[0]
        await viewModel.setCollections(forRecipe: 2, to: [dinner.id])

        // All Saved shows everything.
        #expect(viewModel.displayedRecipes.map(\.id) == [1, 2, 3])
        // Filtered to the collection shows only its members.
        viewModel.selectCollection(dinner.id)
        #expect(viewModel.displayedRecipes.map(\.id) == [2])
    }

    @Test func membershipReflectsWhichCollectionsHoldARecipe() async {
        let dependencies = FakeSavedDependencies()
        dependencies.recipes = [makeRecipe(id: 1)]
        let viewModel = SavedViewModel(dependencies: dependencies)
        await viewModel.refresh()

        await viewModel.addCollection(name: "A")
        await viewModel.addCollection(name: "B")
        let alpha = viewModel.collections[0]
        let beta = viewModel.collections[1]
        await viewModel.setCollections(forRecipe: 1, to: [alpha.id, beta.id])

        #expect(viewModel.membership(forRecipe: 1) == [alpha.id, beta.id])
    }

    @Test func deleteClearsAStaleSelection() async {
        let dependencies = FakeSavedDependencies()
        dependencies.recipes = [makeRecipe(id: 1)]
        let viewModel = SavedViewModel(dependencies: dependencies)
        await viewModel.refresh()

        await viewModel.createCollection(name: "Temp")
        let temp = viewModel.collections[0]
        #expect(viewModel.selectedCollectionID == temp.id)

        await viewModel.deleteCollection(id: temp.id)
        #expect(viewModel.collections.isEmpty)
        #expect(viewModel.selectedCollectionID == nil, "Deleting the selected collection resets to All Saved")
    }

    @Test func renameUpdatesTheShelf() async {
        let dependencies = FakeSavedDependencies()
        dependencies.recipes = [makeRecipe(id: 1)]
        let viewModel = SavedViewModel(dependencies: dependencies)
        await viewModel.refresh()

        await viewModel.createCollection(name: "Old")
        let id = viewModel.collections[0].id
        await viewModel.renameCollection(id: id, name: "New")
        #expect(viewModel.collections.first?.name == "New")
    }
}
