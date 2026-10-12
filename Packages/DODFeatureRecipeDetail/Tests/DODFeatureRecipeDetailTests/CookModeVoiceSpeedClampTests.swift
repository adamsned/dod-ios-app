import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@MainActor
@Suite("Cook Mode voice speed control")
struct CookModeVoiceSpeedTests {
    // MARK: - Speed up tests
    // Speed list reworked to a podcast/audiobook range (0.75 · 1.0 · 1.1 · 1.25
    // · 1.5): the first step up from 1× is now 1.1×, and the top is 1.5×.
    @Test func speedUpFromDefaultAdvancesTo1_1x() {
        let viewModel = CookModeViewModelTests.makeViewModel(stepCount: 1)
        #expect(viewModel.voiceSpeedMultiplier == 1.0)

        viewModel.speedUp()
        #expect(viewModel.voiceSpeedMultiplier == 1.1)
    }

    @Test func speedUpMultipleTimesStaysAtMax() {
        let viewModel = CookModeViewModelTests.makeViewModel(stepCount: 1)
        #expect(viewModel.voiceSpeedMultiplier == 1.0)

        for _ in 0..<8 {
            viewModel.speedUp()
        }
        #expect(viewModel.voiceSpeedMultiplier == 1.5)
    }

    // MARK: - Slow down tests
    @Test func slowDownFromDefaultDropsTo0_75x() {
        let viewModel = CookModeViewModelTests.makeViewModel(stepCount: 1)
        #expect(viewModel.voiceSpeedMultiplier == 1.0)

        viewModel.slowDown()
        #expect(viewModel.voiceSpeedMultiplier == 0.75)
    }

    @Test func slowDownMultipleTimesStaysAtMin() {
        let viewModel = CookModeViewModelTests.makeViewModel(stepCount: 1)
        #expect(viewModel.voiceSpeedMultiplier == 1.0)

        for _ in 0..<8 {
            viewModel.slowDown()
        }
        #expect(viewModel.voiceSpeedMultiplier == 0.75)
    }

    // MARK: - Round-trip speed control
    @Test func speedUpThenSlowDownReturnsToDefault() {
        let viewModel = CookModeViewModelTests.makeViewModel(stepCount: 1)
        #expect(viewModel.voiceSpeedMultiplier == 1.0)

        viewModel.speedUp()
        viewModel.slowDown()
        #expect(viewModel.voiceSpeedMultiplier == 1.0)
    }
}
