import DODSupport
import Foundation

// DUT-967 — live cook coaching. In its own file: CookModeViewModel.swift is at SwiftLint's 400-line limit.
extension CookModeViewModel {

    /// The calm coaching line for the current step + timer state.
    public var currentCoachNudge: String? {
        let timer = stepTimers[currentStepIndex]
        return CookCoachNudge.nudge(
            for: .init(
                stepIndex: currentStepIndex,
                stepCount: stepCount,
                timerRunning: timer?.isRunning ?? false,
                timerCompleted: timer?.state == .completed
            )
        )
    }
}
