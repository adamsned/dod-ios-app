import Foundation

/// DUT-1003 — "Is It Done?" on-device doneness coach surface for ``CookModeViewModel``.
///
/// Extracted from `CookModeViewModel.swift` so the core type body stays under the SwiftLint
/// caps. The photo and the current step text go to the on-device model only; nothing leaves
/// the device. Scope is VISUAL doneness: no temperature or food-safety claims (those stay
/// with a thermometer).
extension CookModeViewModel {

    /// True only when the photo-check button should be shown (model available AND image-capable).
    public var isDonenessCheckAvailable: Bool {
        donenessCoach.isAvailable && currentStep != nil && !isFinished
    }

    /// Read the dish in `photo` against the step currently on screen.
    public func checkDoneness(photo: Data) async {
        guard let step = currentStep, !isFinished else { return }
        await donenessCoach.check(photo: photo, stepText: step.text)
    }

    /// Clear the previous reading (call when the step changes or the sheet closes).
    public func dismissDonenessResult() {
        donenessCoach.reset()
    }
}
