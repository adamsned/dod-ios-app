import DODDesignSystem
import DODSupport
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// US-40 / AC-40.12 + AC-40.13 — the Settings → Cook Mode Voice rows.
//
// CL-279 / DUT-329 — Cook Mode uses ONE voice: the best installed for the device
// language. There is NO in-app voice or gender choice (the gender picker + the
// per-voice picker were removed) and no preview; voices are managed only in the
// iOS Settings app. So these rows are just: a one-line explanation, the resolved
// quality readout (so the user can see they're on the robotic default), and the
// "install a better voice" prompt that points to the Settings app.
//
// `openSettingsURLString` only deep-links to the app's own Settings root (not
// the Accessibility pane), so the prompt copy spells out the full path (CL-123).
//
// Extracted from `SettingsView.swift` so that file stays under the SwiftLint
// file_length cap. `VoiceRows` takes the view-model as a constructor parameter
// (rather than the host's `private @State`) like `CloudSyncRows`. T-752 / CL-149
// renamed `VoiceSection` → `VoiceRows` so the "Customization" section composes
// it with the Appearance picker.

/// Renders the Cook Mode Voice ROWS: a one-line explanation + resolved-quality
/// readout, and — when only the compact (robotic) voice is installed — the
/// dismissible "install a better voice in Settings" prompt.
struct VoiceRows: View {

    @Bindable var viewModel: SettingsViewModel

    /// System `openURL` so the prompt's "Open Settings" deep-links to the app's
    /// Settings root (`UIApplication.openSettingsURLString`).
    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            voiceInfo
            if viewModel.shouldShowDownloadVoiceTip {
                downloadVoiceTip
            }
        }
    }

    // MARK: Rows

    /// The always-shown info: Cook Mode uses the best installed voice, and the
    /// resolved quality tier so the user can see whether they're on the robotic
    /// default. No controls — voices are chosen in the iOS Settings app.
    private var voiceInfo: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xxs) {
            Text("Cook Mode Voice")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
            // The section footer ("The Cook Mode voice reads recipe steps
            // aloud.") is the single description; no inline duplicate here.
            Text("Voice Quality: \(viewModel.resolvedVoiceQuality?.displayName ?? "Unknown")")
                .dodFont(DODType.detail)
                .foregroundStyle(DODColor.labelSecondary)
                .accessibilityIdentifier("settings-voice-quality")
        }
    }

    /// AC-40.13 — the dismissible "install a better voice" prompt. Visible only
    /// when only the compact (robotic) voice is installed and the tip hasn't been
    /// dismissed. The copy spells out the full Settings path because iOS only
    /// deep-links to the app's Settings root (CL-123).
    private var downloadVoiceTip: some View {
        VStack(alignment: .leading, spacing: DODSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: DODSpacing.xs) {
                Text("Want a more natural voice?")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.label)
                Spacer()
                Button {
                    viewModel.dismissDownloadVoiceTip()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(DODColor.labelSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings-voice-tip-dismiss")
                .accessibilityLabel("Dismiss voice tip")
            }
            Text(Self.downloadTipBody)
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                openSettings()
            } label: {
                Text("Open Settings")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.accent)
            }
            .accessibilityIdentifier("settings-voice-tip-open-settings")
        }
        .padding(.vertical, DODSpacing.xxs)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings-voice-download-tip")
    }

    /// The prompt body. Spelled-out path because `openSettingsURLString` only
    /// opens the app's own Settings root, not the Accessibility pane (CL-123).
    static let downloadTipBody =
        "The natural-sounding voices aren't installed yet, so steps may sound robotic. "
        + "In the Settings app, go to Accessibility, then Spoken Content, then Voices, and "
        + "download an Enhanced or Premium voice. It'll be used here automatically."

    // MARK: Actions

    private func openSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
        #endif
    }
}
