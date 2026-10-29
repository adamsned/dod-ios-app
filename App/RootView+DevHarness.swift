import DODDesignSystem
import DODSupport
import SwiftUI

// ============================================================================
// ⚠️ DEV DEBUG — STRIP BEFORE ANY PUBLIC RELEASE ⚠️
//
// App-level test harness for the Settings ▸ Dev Debug ▸ "Testing" buttons.
// Observes the `DevDebug` notifications and fires the matching transient popup
// over the main app so the Snackbar / OfflineBanner / App Welcome surfaces can
// be reviewed on demand (e.g. to eyeball a theme, DUT-1340). Gated on the
// Dev-Debug unlock flag, so a locked (public) install never even wires the
// observers. Strip with the rest of Dev Debug — delete this file and the
// `.modifier(DevPopupHarness(...))` line in `RootView`.
// ============================================================================

/// Renders the dev-fired popups over the app and wires the notification
/// observers. Only active while Dev Debug is unlocked; otherwise it is a
/// pass-through with no observers and no overlays.
struct DevPopupHarness: ViewModifier {

    /// Gate — mirror ``DevDebug/isUnlocked(_:)``. When false this modifier is a
    /// no-op, so a production (locked) build carries no observers or overlays.
    let enabled: Bool

    /// Drives ``RootView``'s real App Welcome cover so "Launch Welcome Screen"
    /// re-presents the exact onboarding the app ships.
    @Binding var showOnboarding: Bool

    @State private var offlineBannerVisible = false
    @State private var saveToastMessage: String?

    func body(content: Content) -> some View {
        if enabled {
            content
                .overlay(alignment: .top) {
                    OfflineBanner(isOffline: offlineBannerVisible)
                }
                // Reuse the app's standard bottom-toast presenter (auto-dismiss,
                // tap-to-dismiss) for the fired save toast.
                .modifier(
                    DeepLinkErrorSnackbar(
                        message: $saveToastMessage,
                        accessibilityID: "dev-save-toast"
                    )
                )
                .onReceive(NotificationCenter.default.publisher(for: .devLaunchWelcome)) { _ in
                    showOnboarding = true
                }
                .onReceive(NotificationCenter.default.publisher(for: .devFireSaveToast)) { _ in
                    saveToastMessage = "Recipe Saved"
                }
                .onReceive(NotificationCenter.default.publisher(for: .devFireOfflineToast)) { _ in
                    offlineBannerVisible = true
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        offlineBannerVisible = false
                    }
                }
        } else {
            content
        }
    }
}
