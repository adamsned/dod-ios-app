import DODDomain
import DODSupport
import Foundation

// MARK: - Cook With Kids (DUT-995)

extension CookModeViewModel {
    /// True when the given step has no knife/heat language.
    public func isKidSafe(_ step: RecipeInstruction) -> Bool {
        KidSafeStepClassifier.isKidSafe(step.text)
    }
}
