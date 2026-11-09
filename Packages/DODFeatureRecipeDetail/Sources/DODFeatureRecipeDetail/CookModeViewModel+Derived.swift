import DODDomain
import DODSupport
import Foundation

// Read-only values derived from public Cook Mode state, kept out of `CookModeViewModel.swift`
// so that file stays under SwiftLint's 400-line `file_length` cap.
extension CookModeViewModel {

    /// DUT-986 — first-cook reassurance + checkpoint for the current step, else nil.
    public var trainingWheelsNote: TrainingWheels.Note? {
        guard !isFinished, let step = currentStep else { return nil }
        return TrainingWheels.note(forStepText: step.text, isFirstCookEver: isFirstCookEver)
    }

    /// Heat profile for the cast-iron rescue tips; `nil` without an explicit temperature.
    public var rescueHeatProfile: RecipeHeatProfile.Derived? { RecipeHeatProfile.derive(from: recipe) }
}
