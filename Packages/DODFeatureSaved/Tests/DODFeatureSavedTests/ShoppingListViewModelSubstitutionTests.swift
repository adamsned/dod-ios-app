import DODDomain
import DODIntelligence
import Foundation
import Testing

@testable import DODFeatureSaved

/// L1 coverage for the v2 on-device-AI substitution seam on
/// ``ShoppingListViewModel`` — the availability-driven visibility flag and the
/// loading → loaded / notFound state machine (constitution §6 L1 mandate).
///
/// The live model is unavailable in the simulator / CI and non-deterministic,
/// so these drive a ``FakeIntelligenceService`` — the seam, never the model.
@MainActor
@Suite("ShoppingListViewModel — substitution (v2 AI)")
struct ShoppingListViewModelSubstitutionTests {

    private static func item(_ text: String) -> ShoppingListViewModel.Item {
        ShoppingListViewModel.Item(ingredientText: text, recipeTitle: "R", aisle: .produce)
    }

    @Test func affordanceHiddenWhenNoServiceInjected() {
        let viewModel = ShoppingListViewModel(items: [], store: nil)
        #expect(!viewModel.isSubstitutionAvailable)
    }

    @Test func affordanceHiddenWhenServiceUnavailable() {
        let viewModel = ShoppingListViewModel(
            items: [],
            store: nil,
            intelligence: FakeIntelligenceService(isAvailable: false)
        )
        #expect(!viewModel.isSubstitutionAvailable)
    }

    @Test func affordanceShownWhenServiceAvailable() {
        let viewModel = ShoppingListViewModel(
            items: [],
            store: nil,
            intelligence: FakeIntelligenceService(isAvailable: true)
        )
        #expect(viewModel.isSubstitutionAvailable)
    }

    @Test func requestExposesCannedSubstitution() async {
        let viewModel = ShoppingListViewModel(
            items: [],
            store: nil,
            intelligence: FakeIntelligenceService(isAvailable: true, substitution: .cannedButtermilk)
        )
        await viewModel.requestSubstitution(for: Self.item("1 cup buttermilk"))
        #expect(
            viewModel.substitution
                == .loaded(
                    ingredient: "1 cup buttermilk",
                    substitution: .cannedButtermilk
                )
        )
    }

    @Test func requestWithNoResultLandsInNotFound() async {
        let viewModel = ShoppingListViewModel(
            items: [],
            store: nil,
            intelligence: FakeIntelligenceService(isAvailable: true, substitution: nil)
        )
        await viewModel.requestSubstitution(for: Self.item("unobtanium"))
        #expect(viewModel.substitution == .notFound(ingredient: "unobtanium"))
    }

    @Test func requestIsNoOpWhenUnavailable() async {
        let viewModel = ShoppingListViewModel(
            items: [],
            store: nil,
            intelligence: FakeIntelligenceService(isAvailable: false)
        )
        await viewModel.requestSubstitution(for: Self.item("1 cup buttermilk"))
        // Never leaves idle — no empty sheet on an unsupported device.
        #expect(viewModel.substitution == .idle)
    }

    @Test func dismissReturnsToIdle() async {
        let viewModel = ShoppingListViewModel(
            items: [],
            store: nil,
            intelligence: FakeIntelligenceService(isAvailable: true)
        )
        await viewModel.requestSubstitution(for: Self.item("1 cup buttermilk"))
        #expect(viewModel.substitution != .idle)
        viewModel.dismissSubstitution()
        #expect(viewModel.substitution == .idle)
    }
}
