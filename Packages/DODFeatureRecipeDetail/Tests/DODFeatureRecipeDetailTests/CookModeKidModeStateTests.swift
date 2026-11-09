import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@MainActor
@Suite("CookModeViewModel kid mode state (DUT-995)")
struct CookModeKidModeStateTests {

    @Test func kidModeIsOffByDefault() {
        let viewModel = CookModeViewModelTests.makeViewModel(stepCount: 3)
        #expect(!viewModel.isKidModeEnabled)
    }

    @Test func endCookModeTurnsKidModeOff() {
        let viewModel = CookModeViewModelTests.makeViewModel(stepCount: 3)
        viewModel.beginCookMode()
        viewModel.isKidModeEnabled = true
        viewModel.endCookMode()
        #expect(!viewModel.isKidModeEnabled)
    }
}
