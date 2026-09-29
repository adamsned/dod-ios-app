import DODDomain
import DODIntelligence
import Foundation
import Testing

@testable import DODFeatureSaved

/// L1 coverage for the v2 on-device-AI substitution seam on
/// ``ShoppingListViewModel`` — the availability flag and the pickingReason →
/// loading → loaded / notFound state machine, plus Apply replacing the row
/// (constitution §6 L1 mandate).
///
/// The live model is unavailable in the simulator / CI and non-deterministic,
/// so these drive a ``FakeIntelligenceService`` — the seam, never the model.
@MainActor
@Suite("ShoppingListViewModel — substitution (v2 AI)")
struct ShoppingListViewModelSubstitutionTests {

    private static func item(_ text: String) -> ShoppingListViewModel.Item {
        ShoppingListViewModel.Item(ingredientText: text, recipeTitle: "R", aisle: .produce)
    }

    private static func model(
        items: [ShoppingListViewModel.Item] = [],
        isAvailable: Bool = true,
        substitution: IngredientSubstitution? = .cannedButtermilk
    ) -> ShoppingListViewModel {
        ShoppingListViewModel(
            items: items,
            store: nil,
            intelligence: FakeIntelligenceService(isAvailable: isAvailable, substitution: substitution)
        )
    }

    // MARK: - Availability gate

    @Test func affordanceHiddenWhenNoServiceInjected() {
        #expect(!ShoppingListViewModel(items: [], store: nil).isSubstitutionAvailable)
    }

    @Test func affordanceHiddenWhenServiceUnavailable() {
        #expect(!Self.model(isAvailable: false).isSubstitutionAvailable)
    }

    @Test func affordanceShownWhenServiceAvailable() {
        #expect(Self.model(isAvailable: true).isSubstitutionAvailable)
    }

    // MARK: - Flow

    @Test func beginOpensTheReasonPicker() {
        let target = Self.item("1 cup buttermilk")
        let viewModel = Self.model(items: [target])
        viewModel.beginSubstitution(for: target)
        #expect(viewModel.substitution == .pickingReason(itemID: target.id, ingredient: "1 cup buttermilk"))
    }

    @Test func beginIsNoOpWhenUnavailable() {
        let target = Self.item("1 cup buttermilk")
        let viewModel = Self.model(items: [target], isAvailable: false)
        viewModel.beginSubstitution(for: target)
        // Never leaves idle — no empty sheet on an unsupported device.
        #expect(viewModel.substitution == .idle)
    }

    @Test func generateExposesCannedSubstitution() async {
        let target = Self.item("1 cup buttermilk")
        let viewModel = Self.model(items: [target], substitution: .cannedButtermilk)
        viewModel.beginSubstitution(for: target)
        await viewModel.generateSubstitution(reason: .dairyFree)
        #expect(
            viewModel.substitution
                == .loaded(itemID: target.id, ingredient: "1 cup buttermilk", substitution: .cannedButtermilk)
        )
    }

    @Test func generateWithNoResultLandsInNotFound() async {
        let target = Self.item("unobtanium")
        let viewModel = Self.model(items: [target], substitution: nil)
        viewModel.beginSubstitution(for: target)
        await viewModel.generateSubstitution(reason: nil)
        #expect(viewModel.substitution == .notFound(itemID: target.id, ingredient: "unobtanium"))
    }

    // MARK: - Apply

    @Test func applyReplacesTheRowInPlace() async {
        let target = Self.item("1 cup buttermilk")
        let viewModel = Self.model(items: [target], substitution: .cannedButtermilk)
        viewModel.beginSubstitution(for: target)
        await viewModel.generateSubstitution(reason: nil)
        viewModel.applySubstitution()

        // Same row id, new ingredient text, sheet dismissed.
        #expect(viewModel.items.count == 1)
        #expect(viewModel.items.first?.id == target.id)
        #expect(viewModel.items.first?.ingredientText == IngredientSubstitution.cannedButtermilk.substitute)
        #expect(viewModel.items.first?.recipeTitle == "R")
        #expect(viewModel.substitution == .idle)
    }

    @Test func applyIsNoOpUnlessLoaded() {
        let viewModel = Self.model(items: [Self.item("1 cup buttermilk")])
        viewModel.applySubstitution()  // state is .idle
        #expect(viewModel.substitution == .idle)
        #expect(viewModel.items.first?.ingredientText == "1 cup buttermilk")
    }

    @Test func dismissReturnsToIdle() async {
        let target = Self.item("1 cup buttermilk")
        let viewModel = Self.model(items: [target])
        viewModel.beginSubstitution(for: target)
        await viewModel.generateSubstitution(reason: nil)
        #expect(viewModel.substitution != .idle)
        viewModel.dismissSubstitution()
        #expect(viewModel.substitution == .idle)
    }
}
