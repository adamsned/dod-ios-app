import Foundation

/// DUT-173 — opt-in "auto-advance when a step timer finishes" preference.
public enum CookModeAutoAdvance {

    /// `UserDefaults` / `@AppStorage` key. Stored as a Bool.
    public static let preferenceKey = "dod.settings.cookModeAutoAdvanceOnTimer"

    /// Off unless the user opts in.
    public static let defaultEnabled = false

    /// Seconds the "Advancing to step N…" Undo banner stays up before it is dismissed.
    public static let undoWindowSeconds: Double = 5

    /// Pure decision helper: should a finished timer on `completedStep` advance Cook Mode?
    /// Only when the setting is on, the timer belongs to the step currently shown,
    /// and it is not the last step.
    public static func shouldAdvance(
        enabled: Bool,
        completedStep: Int,
        currentStep: Int,
        stepCount: Int
    ) -> Bool {
        enabled && completedStep == currentStep && completedStep < stepCount - 1
    }
}
