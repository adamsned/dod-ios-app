import DODFeatureProfile
import DODSupport
import Foundation
import SwiftUI

// DUT-635 (wire) — the merged Profile PR added `AppleCredentialValidator` with
// `validateOnLaunchOrForeground()` and `startObservingRevocation()`, but the
// package can't reach the App's scene lifecycle, so the composition root wires
// them: validate on launch AND on `scenePhase == .active`, and retain the
// revocation observer for the app's lifetime.
//
// Extracted from `RootView.swift` so that file stays under the SwiftLint
// `file_length` cap (mirrors the other `RootView+*.swift` splits).
extension RootView {

    /// DUT-635 (wire) — build the production validator with the app's Keychain
    /// profile store (and the default Apple session store / SIWA revoker
    /// `makeProduction` wires). `onSessionCleared` logs the reaction; the coupled
    /// profile / session / guest rows are already torn down by the validator.
    private func makeAppleCredentialValidator() -> AppleCredentialValidator {
        AppleCredentialValidator.makeProduction(
            profileStore: dependencies.profileStore,
            onSessionCleared: {
                DODLog.app.notice("Apple credential revoked; local session cleared.")
            }
        )
    }

    /// DUT-635 (wire) — launch path: validate the stored credential once, then
    /// install the live revocation observer (retained for the app's lifetime via
    /// `appleCredentialRevocationObserver`, so it isn't installed twice on a
    /// spurious `.task` re-run).
    func validateAppleCredentialOnLaunch() async {
        let validator = makeAppleCredentialValidator()
        await validator.validateOnLaunchOrForeground()
        if appleCredentialRevocationObserver == nil {
            appleCredentialRevocationObserver = validator.startObservingRevocation()
        }
    }

    /// DUT-635 (wire) — foreground path: re-poll on every `scenePhase == .active`
    /// so a revocation while backgrounded clears the session (per
    /// `validateOnLaunchOrForeground()`'s contract).
    func validateAppleCredentialOnForeground() async {
        await makeAppleCredentialValidator().validateOnLaunchOrForeground()
    }
}
