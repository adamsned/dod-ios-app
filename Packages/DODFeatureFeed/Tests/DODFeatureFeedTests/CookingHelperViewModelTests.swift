import DODIntelligence
import Foundation
import Testing

@testable import DODFeatureFeed

/// L1 coverage for the T-934 (US-54 / AC-54.4) Cooking Tools AI helper view
/// model — the availability-driven visibility flag and the loading → loaded /
/// notFound state machine (constitution §6 L1 mandate).
///
/// The live model is unavailable in the simulator / CI and non-deterministic,
/// so these drive a ``FakeIntelligenceService`` — the seam, never the model.
@MainActor
@Suite("CookingHelperViewModel (v2 AI)")
struct CookingHelperViewModelTests {

    @Test func helperHiddenWhenNoServiceInjected() {
        let viewModel = CookingHelperViewModel(intelligence: nil)
        #expect(!viewModel.isAvailable)
    }

    @Test func helperHiddenWhenServiceUnavailable() {
        let viewModel = CookingHelperViewModel(
            intelligence: FakeIntelligenceService(isAvailable: false)
        )
        #expect(!viewModel.isAvailable)
    }

    @Test func helperShownWhenServiceAvailable() {
        let viewModel = CookingHelperViewModel(
            intelligence: FakeIntelligenceService(isAvailable: true)
        )
        #expect(viewModel.isAvailable)
    }

    @Test func askExposesTheAnswer() async {
        let viewModel = CookingHelperViewModel(
            intelligence: FakeIntelligenceService(isAvailable: true, answer: "Warm it gradually.")
        )
        viewModel.question = "How do I season a skillet?"
        await viewModel.ask()
        #expect(viewModel.answer == .loaded("Warm it gradually."))
    }

    @Test func askWithNoResultLandsInNotFound() async {
        let viewModel = CookingHelperViewModel(
            intelligence: FakeIntelligenceService(isAvailable: true, answer: nil)
        )
        viewModel.question = "How do I season a skillet?"
        await viewModel.ask()
        #expect(viewModel.answer == .notFound)
    }

    @Test func askIsNoOpWhenUnavailable() async {
        let viewModel = CookingHelperViewModel(
            intelligence: FakeIntelligenceService(isAvailable: false)
        )
        viewModel.question = "How do I season a skillet?"
        await viewModel.ask()
        // Never leaves idle — no empty sheet on an unsupported device.
        #expect(viewModel.answer == .idle)
    }

    @Test func askIsNoOpWhenQuestionBlank() async {
        let viewModel = CookingHelperViewModel(
            intelligence: FakeIntelligenceService(isAvailable: true)
        )
        viewModel.question = "   "
        await viewModel.ask()
        #expect(viewModel.answer == .idle)
    }

    @Test func resetReturnsToIdle() async {
        let viewModel = CookingHelperViewModel(
            intelligence: FakeIntelligenceService(isAvailable: true)
        )
        viewModel.question = "How do I season a skillet?"
        await viewModel.ask()
        #expect(viewModel.answer != .idle)
        viewModel.reset()
        #expect(viewModel.answer == .idle)
    }
}
