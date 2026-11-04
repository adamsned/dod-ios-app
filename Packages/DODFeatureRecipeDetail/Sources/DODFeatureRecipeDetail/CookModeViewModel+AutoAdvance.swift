import DODSupport
import Foundation

extension CookModeViewModel {

    /// DUT-173 — called when the timer on `step` reaches zero. If the setting is on
    /// and the step is the one on screen (and not the last), advance via `goNext()`,
    /// which already re-reads the new step when Voice Mode is on, and remember
    /// where we came from so Undo can return. Returns true when it advanced.
    @discardableResult
    public func autoAdvanceAfterTimer(completedStep step: Int) -> Bool {
        guard
            CookModeAutoAdvance.shouldAdvance(
                enabled: autoAdvanceEnabled,
                completedStep: step,
                currentStep: currentStepIndex,
                stepCount: stepCount
            )
        else { return false }
        pendingAutoAdvanceFromStep = step
        goNext()
        return true
    }

    /// Undo the auto-advance: jump back to the step we left and clear the banner.
    /// No-op when no banner is pending.
    public func undoAutoAdvance() {
        guard let from = pendingAutoAdvanceFromStep else { return }
        pendingAutoAdvanceFromStep = nil
        goToStep(from)
    }

    /// Dismiss the banner without going back (window elapsed).
    public func dismissAutoAdvanceBanner() {
        pendingAutoAdvanceFromStep = nil
    }
}
