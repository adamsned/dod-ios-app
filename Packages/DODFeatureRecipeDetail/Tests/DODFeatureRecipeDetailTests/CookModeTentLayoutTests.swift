import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// DUT-1017 — the rule `CookModeView.tentLayout` hangs on: tent posture uses the
/// two-pane layout while cooking, and the Done card goes back to a single pane.
@MainActor
@Suite("CookMode tent layout")
struct CookModeTentLayoutTests {

    @Test func tentUsesTwoPaneUntilFinished() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 3)
        #expect(CookModePosture.tent.usesTwoPane(isFinished: vm.isFinished))
        while !vm.isFinished { vm.goNext() }
        #expect(!CookModePosture.tent.usesTwoPane(isFinished: vm.isFinished))
    }
}
