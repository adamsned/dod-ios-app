import DODIntelligence
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@MainActor
@Suite("CookModeViewModel doneness coach (DUT-1003)") struct CookModeViewModelDonenessTests {
    private func makeViewModel(supportsImageInput: Bool = true, stepCount: Int = 2) -> CookModeViewModel {
        CookModeViewModelTests.makeViewModel(
            stepCount: stepCount,
            donenessCoach: DonenessCoach(
                intelligence: FakeIntelligenceService(supportsImageInput: supportsImageInput)
            )
        )
    }

    @Test func donenessCoachDefaultsToUnavailable() {
        #expect(CookModeViewModelTests.makeViewModel(stepCount: 2).donenessCoach.isAvailable == false)
    }

    @Test func checkAvailableWithImageCapableFake() {
        #expect(makeViewModel().isDonenessCheckAvailable)
    }

    @Test func checkUnavailableWithoutImageInput() {
        #expect(!makeViewModel(supportsImageInput: false).isDonenessCheckAvailable)
    }

    @Test func checkDonenessProducesResult() async {
        let viewModel = makeViewModel()
        await viewModel.checkDoneness(photo: Data([1, 2, 3]))
        guard case .result = viewModel.donenessCoach.state else {
            Issue.record("expected .result, got \(viewModel.donenessCoach.state)")
            return
        }
    }

    @Test func checkDonenessIgnoredWhenFinished() async {
        let viewModel = makeViewModel(stepCount: 1)
        viewModel.goNext()  // past the last step -> isFinished
        #expect(viewModel.isFinished)
        await viewModel.checkDoneness(photo: Data([1, 2, 3]))
        #expect(viewModel.donenessCoach.state == .idle)
    }

    @Test func dismissReturnsToIdle() async {
        let viewModel = makeViewModel()
        await viewModel.checkDoneness(photo: Data([1, 2, 3]))
        viewModel.dismissDonenessResult()
        #expect(viewModel.donenessCoach.state == .idle)
    }
}
