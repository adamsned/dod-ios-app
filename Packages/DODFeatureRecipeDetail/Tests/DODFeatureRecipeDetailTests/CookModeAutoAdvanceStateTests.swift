import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// DUT-173 — stored state for auto-advancing when a step timer finishes.
@MainActor
@Suite("CookModeViewModel auto-advance state")
struct CookModeAutoAdvanceStateTests {

    @Test func newViewModelDefaultsToOffWithNoPendingBanner() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 2)
        #expect(vm.autoAdvanceEnabled == false)
        #expect(vm.pendingAutoAdvanceFromStep == nil)
    }

    @Test func endCookModeClearsPendingAutoAdvance() {
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 2)
        vm.beginCookMode()
        vm.endCookMode()
        #expect(vm.pendingAutoAdvanceFromStep == nil)
    }
}
