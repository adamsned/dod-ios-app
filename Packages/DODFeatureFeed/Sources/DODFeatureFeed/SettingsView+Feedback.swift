import DODDesignSystem
import DODSupport
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// DUT-694 (PR-D) — the Settings cache-clear feedback (snackbar overlay + the
// Clear Cache action) lives here so `SettingsView.swift` stays under the
// SwiftLint 400-line `file_length` cap once the DUT-694 in-flight guard + success
// haptic land (the same partitioning rule `SettingsView+Bindings.swift` follows).
extension SettingsView {

    /// Snackbar overlay for the cache-clear feedback (AC-36.4). Hidden
    /// when the view-model has no message; auto-dismisses on tap.
    @ViewBuilder
    var snackbarOverlay: some View {
        if let message = viewModel.snackbarMessage {
            Snackbar(message: message)
                // DUT-362: key the overlay by the message so a NEW message gives it
                // fresh identity and restarts the 4s auto-dismiss `.task` (otherwise
                // the first message's timer fires and clears the second one early).
                .id(message)
                .padding(.bottom, DODSpacing.md)
                // DUT-529: under Reduce Motion, drop the slide and crossfade in
                // with opacity only (constitution §7); otherwise slide up + fade.
                .transition(
                    reduceMotion
                        ? .opacity
                        : .move(edge: .bottom).combined(with: .opacity)
                )
                .onTapGesture { viewModel.dismissSnackbar() }
                .task {
                    // Auto-dismiss after 4 seconds. Matches the Snackbar
                    // component's documented default presentation length.
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    viewModel.dismissSnackbar()
                }
                .accessibilityIdentifier("settings-snackbar")
        }
    }

    // MARK: - Actions

    /// Clear the cached recipe images, guarding against a concurrent run.
    ///
    /// DUT-694 (PR-D) — a double-tap previously kicked off two overlapping clears
    /// and showed contradictory snackbars ("Freed X MB" then "already clear"). The
    /// `isClearingCache` flag (also `.disabled`-ing the button) collapses a rapid
    /// re-tap into a no-op so only one clear runs and one snackbar shows.
    func clearImageCacheIfAvailable() async {
        guard !isClearingCache else { return }
        isClearingCache = true
        defer { isClearingCache = false }

        guard let onClearImageCache else {
            // No closure wired (preview / snapshot host). Surface the
            // zero-case copy so the button still gives feedback rather
            // than appearing broken in design surfaces.
            viewModel.previewCacheClearMessage()
            return
        }
        await viewModel.clearImageCache(onClear: onClearImageCache)
    }

    #if canImport(UIKit)
    /// **Daddy Mode (Phase 1) — activation aid.** Discreet, release-safe
    /// diagnostic on the version footer: a long-press copies the CURRENT
    /// signed-in user's Sign in with Apple `sub` (``AppleAuthSession/userIdentifier``,
    /// read through the same on-device store the rest of the app uses) to the
    /// pasteboard so the owner can send it to us to configure
    /// `OwnerGate.ownerUserIdentifier`. Not `#if DEBUG`-gated (Dad runs
    /// TestFlight) and NOT owner-gated (we don't know his `sub` yet — that is
    /// the whole point). The raw value is never shown on screen — only a neutral
    /// "Diagnostic ID copied" confirmation. No session ⇒ copy nothing + prompt to
    /// sign in.
    func copyDiagnosticIdentifier() {
        let sub = (try? KeychainAppleAuthSessionStore().load())?.userIdentifier
        guard let sub, !sub.isBlankAppleIdentifier else {
            viewModel.snackbarMessage = "Sign in first"
            return
        }
        UIPasteboard.general.string = sub
        viewModel.snackbarMessage = "Diagnostic ID copied"
    }
    #endif
}
