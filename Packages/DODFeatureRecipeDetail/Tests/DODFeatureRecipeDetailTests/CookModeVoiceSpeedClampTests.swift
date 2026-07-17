import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@MainActor
@Suite("Cook Mode voice speed control")
struct CookModeVoiceSpeedTests {
    // MARK: - Speed up tests
    @Test func speedUpFromDefaultAdvancesTo1_25x() {
        let viewModel = CookModeViewModelTests.makeViewModel(stepCount: 1)
        #expect(viewModel.voiceSpeedMultiplier == 1.0)

        viewModel.speedUp()
        #expect(viewModel.voiceSpeedMultiplier == 1.25)
    }

    @Test func speedUpMultipleTimesStaysAtMax() {
        let viewModel = CookModeViewModelTests.makeViewModel(stepCount: 1)
        #expect(viewModel.voiceSpeedMultiplier == 1.0)

        for _ in 0..<8 {
            viewModel.speedUp()
        }
        #expect(viewModel.voiceSpeedMultiplier == 2.0)
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
        #expect(viewModel.voiceSpeedMultiplier == 0.5)
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
