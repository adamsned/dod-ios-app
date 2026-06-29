import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// DUT-328 — the one-time Cook Mode "this may sound robotic, get a better voice"
// prompt, extracted into a self-contained `ViewModifier` so `CookModeView`'s
// body stays a single line and under the SwiftLint `type_body_length` cap. The
// modifier owns its own presentation + once-per-session state, so none of it
// lives on the `CookModeView` struct.

extension View {

    /// DUT-328 — attach the one-time "get a better voice" prompt: the first time
    /// Voice Mode is turned on in a session while only a robotic voice is
    /// installed, a dismissible alert offers the upgrade. Voice Mode still works
    /// (it reads aloud robotically) — this is an upsell, never a blocker.
    func cookModeVoiceUpgradePrompt(viewModel: CookModeViewModel) -> some View {
        modifier(CookModeVoiceUpgradePrompt(viewModel: viewModel))
    }
}

/// Owns the prompt's presentation + the once-per-session guard so repeated
/// speaker taps never nag.
private struct CookModeVoiceUpgradePrompt: ViewModifier {

    let viewModel: CookModeViewModel
    @State private var isPresented = false
    @State private var hasOffered = false
    /// `openURL` so "Open Settings" jumps to the app's Settings root
    /// (`UIApplication.openSettingsURLString`).
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content
            // DUT-348: evaluate on the false→true transition AND on appear, so an
            // already-Voice-Mode-on state at mount still offers the upgrade
            // (onChange alone only sees a transition after the modifier mounts).
            .onChange(of: viewModel.isVoiceModeEnabled) { _, _ in offerUpgradeIfNeeded() }
            .onAppear { offerUpgradeIfNeeded() }
            .alert("Want a more natural voice?", isPresented: $isPresented) {
                Button("Open Settings") { openVoiceSettings() }
                Button("Not Now", role: .cancel) {}
            } message: {
                Text(
                    "Cook Mode steps may sound robotic. In the Settings app, open "
                        + "Accessibility, then Read & Speak, then Voices, and download an "
                        + "Enhanced or Premium voice. It'll be used here automatically."
                )
            }
    }

    /// DUT-348 — show the one-time upgrade offer when Voice Mode is on, it hasn't
    /// been offered this session, and only a robotic voice is installed. Called
    /// from both `.onChange` and `.onAppear` so an already-on-at-mount state is
    /// covered, not just the transition.
    private func offerUpgradeIfNeeded() {
        guard viewModel.isVoiceModeEnabled, !hasOffered, viewModel.shouldOfferVoiceUpgrade else {
            return
        }
        hasOffered = true
        isPresented = true
    }

    /// Deep-link to the app's Settings root. iOS only exposes the app's own
    /// Settings page (not the Accessibility → Read & Speak → Voices pane), so
    /// the message copy spells out the path (matching the Settings nudge, CL-123).
    private func openVoiceSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
        #endif
    }
}
