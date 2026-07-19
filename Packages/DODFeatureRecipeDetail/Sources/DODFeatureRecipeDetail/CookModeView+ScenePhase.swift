import SwiftUI

// DUT-529 / DUT-558 — scene-activate/deactivate handling, split from
// `CookModeView.swift` for the SwiftLint file-length cap.
extension CookModeView {

    /// The scene-activate/deactivate handling extracted to a static function of
    /// (phase, viewModel) so it's directly unit-testable without hosting a live
    /// view hierarchy (the View's own `@State` doesn't round-trip mutations when
    /// instantiated standalone, but `viewModel` here is a plain class reference,
    /// so calling its methods is sound).
    ///
    /// DUT-558 fix: `reconcileLiveActivity` latches `liveActivityUnavailable`
    /// once ActivityKit reports Live Activities are disabled/over quota, and
    /// stops retrying the start every tick. That latch was documented as
    /// clearing "on scene-activate" (see `revalidateLiveActivityAvailability()`)
    /// but nothing ever called it — the user could re-enable Live Activities in
    /// Settings, return to the app, and the card would stay dead for the rest of
    /// that Cook Mode session (only fully leaving and restarting Cook Mode
    /// recovered it, since that creates a fresh view model). Revalidating on
    /// every `.active` transition, alongside the existing idle-timer re-arm,
    /// closes that gap.
    static func handleScenePhaseChange(_ newPhase: ScenePhase, viewModel: CookModeViewModel) {
        switch newPhase {
        case .background:
            viewModel.suspendIdleTimerForBackground()
        case .active:
            viewModel.resumeIdleTimerIfActive()
            viewModel.revalidateLiveActivityAvailability()
        default:
            break
        }
    }
}
