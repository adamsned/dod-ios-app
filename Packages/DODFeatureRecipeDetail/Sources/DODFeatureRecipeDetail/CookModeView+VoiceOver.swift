import DODSupport
import Foundation
import SwiftUI

// DUT-116 — VoiceOver awareness for Cook Mode: swipe gating, rotor, announcements.
extension CookModeView {
    /// With VoiceOver on, the view's own swipe gesture is dropped (`.subviews`
    /// keeps child gestures only) so it can't fight VoiceOver's swipes.
    nonisolated static func swipeGestureMask(voiceOverEnabled: Bool) -> GestureMask {
        voiceOverEnabled ? .subviews : .all
    }

    func announceTimerComplete() {
        announce(
            CookModeAccessibilityPhrasing.timerCompleteAnnouncement(
                stepNumber: viewModel.currentStepIndex + 1
            )
        )
    }

    func handleStepChange() {
        announceCurrentStep()
        if voiceOverEnabled { stepFocused = true }
    }

    var stepIngredientLines: [String] {
        CookModeStepIngredientMatcher.matching(
            stepText: viewModel.currentStep?.text ?? "",
            ingredients: viewModel.recipe.ingredients.map(\.text)
        )
    }

    var rotorItems: [CookModeRotorItem] {
        CookModeRotorItem.available(
            hasNextStep: !viewModel.isFinished && !viewModel.isOnLastStep,
            hasActiveTimer: viewModel.stepTimers.values.contains { $0.isRunning },
            hasStepIngredients: !stepIngredientLines.isEmpty
        )
    }

    func handleRotor(_ item: CookModeRotorItem) {
        let total = viewModel.stepCount
        switch item {
        case .currentStep: announceCurrentStep()
        case .nextStep:
            let next = viewModel.currentStepIndex + 1
            if viewModel.recipe.instructions.indices.contains(next) {
                let step = viewModel.recipe.instructions[next]
                announce(
                    CookModeAccessibilityPhrasing.stepLabel(
                        number: next + 1,
                        total: total,
                        text: convertedStepText(step.text)
                    )
                )
            }
        case .stepIngredients:
            announce(CookModeAccessibilityPhrasing.ingredientsSummary(stepIngredientLines))
        case .activeTimer:
            if let timer = viewModel.stepTimers.values.first(where: { $0.isRunning }) {
                announce(
                    CookModeAccessibilityPhrasing.timerStatus(
                        remainingSeconds: timer.remaining(at: Date())
                    )
                )
            }
        case .exit: close()
        }
    }
}
