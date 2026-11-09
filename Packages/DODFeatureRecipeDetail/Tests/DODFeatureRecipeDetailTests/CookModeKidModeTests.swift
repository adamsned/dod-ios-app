import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@MainActor
@Suite("CookModeViewModel kid mode (DUT-995)") struct CookModeKidModeTests {

    @Test func kidModeDefaultsOff() {
        let viewModel = CookModeViewModelTests.makeViewModel(stepCount: 2)
        #expect(viewModel.isKidModeEnabled == false)
    }

    @Test func endCookModeResetsKidMode() {
        let viewModel = CookModeViewModelTests.makeViewModel(stepCount: 2)
        viewModel.beginCookMode()
        viewModel.isKidModeEnabled = true
        viewModel.endCookMode()
        #expect(viewModel.isKidModeEnabled == false)
    }

    @Test func isKidSafeFalseForKnifeStep() {
        let viewModel = CookModeViewModelTests.makeViewModel(stepCount: 2)
        #expect(viewModel.isKidSafe(RecipeInstruction(step: 1, text: "Chop the onion.")) == false)
    }

    @Test func isKidSafeTrueForPlainStep() {
        let viewModel = CookModeViewModelTests.makeViewModel(stepCount: 2)
        #expect(viewModel.isKidSafe(RecipeInstruction(step: 1, text: "Stir the sauce.")) == true)
    }
}
