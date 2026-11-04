import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@MainActor
@Suite("Cook Mode probe wiring (DUT-135)") struct CookModeViewModelProbeWiringTests {
    @Test func probeStartsIdleWithoutTarget() {
        let viewModel = CookModeViewModelTests.makeViewModel(stepCount: 2)
        #expect(viewModel.probe.targetF == nil)
        #expect(viewModel.probe.connection == .idle)
    }
}
