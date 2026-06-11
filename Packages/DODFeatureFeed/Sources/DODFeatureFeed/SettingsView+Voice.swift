import DODDesignSystem
import DODSupport
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// US-40 / AC-40.10 + AC-40.12 + AC-40.13 — the Settings → Cook Mode Voice
// section: gender picker (T-721), resolved-quality readout + Preview button
// (T-721), and the "download a better voice" nudge (T-722).
//
// Extracted from `SettingsView.swift` so that file stays under the SwiftLint
// 400-line file_length cap — the same split `SettingsView+CloudSync.swift`
// uses. `VoiceSection` takes the view-model as a constructor parameter (rather
// than reaching for the host's `private @State`) exactly like `CloudSyncSection`.
//
// Why a nudge instead of an in-app download: Apple ships only the compact
// ("robotic") voice tier preinstalled, and there is NO public API to bundle or
// trigger a download of the natural Enhanced/Premium tiers — the user must
// fetch them in iOS Settings → Accessibility → Spoken Content → Voices. iOS's
// `openSettingsURLString` only deep-links to the app's own Settings root (not
// the Accessibility pane), so the tip copy spells out the full path (CL-123).

// MARK: - Voice section

/// Renders the "Cook Mode Voice" section: the gender `Picker`, the resolved
/// quality readout, the Preview-voice button, and — when only the compact
/// (robotic) voice is installed for the device language — the dismissible
/// download nudge.
struct VoiceSection: View {

    @Bindable var viewModel: SettingsViewModel

    /// System `openURL` so the nudge's "Open Settings" button can deep-link to
    /// the app's Settings root (`UIApplication.openSettingsURLString`). Uses the
    /// environment action rather than `UIApplication.shared.open` so the type
    /// compiles on the macOS `swift test` slice (UIKit-free) and stays testable.
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section {
            picker
            qualityReadoutRow
            previewButton
            if viewModel.shouldShowDownloadVoiceTip {
                downloadVoiceTip
            }
        } footer: {
            Text("Used when reading recipe steps aloud in Cook Mode.")
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
        }
        .listRowBackground(DODColor.surfaceElevated)
        // Stop any in-flight preview when the user leaves Settings so a
        // sample never trails off-screen.
        .onDisappear { viewModel.stopVoicePreview() }
    }

    // MARK: Rows

    /// AC-40.10 — the Female / Male / No-preference gender picker. Identifier
    /// unchanged from T-721 so existing UI coverage keeps resolving it.
    private var picker: some View {
        Picker(selection: voiceGenderBinding) {
            ForEach(VoiceGender.allCases, id: \.self) { value in
                Text(value.displayName)
                    .tag(value)
            }
        } label: {
            Text("Cook Mode Voice")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
        }
        .accessibilityIdentifier("settings-picker-voice-gender")
    }

    /// AC-40.12 — read-only "Voice quality → Default/Enhanced/Premium" row so
    /// the user can SEE whether they're on a robotic (Default) voice. Renders
    /// "Unknown" when no catalog is available (no previewer wired) rather than
    /// guessing a tier.
    private var qualityReadoutRow: some View {
        HStack {
            Text("Voice Quality")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
            Spacer()
            Text(viewModel.resolvedVoiceQuality?.displayName ?? "Unknown")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("settings-voice-quality")
    }

    /// AC-40.12 — speaks the fixed sample line with the current pick so the
    /// user hears the difference before committing. Inert (no-op) when no
    /// previewer is wired.
    private var previewButton: some View {
        Button {
            viewModel.previewVoice()
        } label: {
            Label("Preview Voice", systemImage: "speaker.wave.2.fill")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.accent)
        }
        .accessibilityIdentifier("settings-button-voice-preview")
        .accessibilityHint("Plays a sample recipe step in the selected voice.")
    }

    /// AC-40.13 — the dismissible "download a better voice" nudge. Visible only
    /// when ``SettingsViewModel/shouldShowDownloadVoiceTip`` is true (compact-
    /// only catalog, not previously dismissed). The copy spells out the full
    /// Settings path because iOS only deep-links to the app's Settings root.
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

    /// The nudge body copy. Spelled-out path because
    /// `UIApplication.openSettingsURLString` only opens the app's own Settings
    /// root, not the Accessibility pane (CL-123).
    static let downloadTipBody =
        "The natural-sounding voices aren't installed yet, so steps may sound robotic. "
        + "In the Settings app, go to Accessibility → Spoken Content → Voices → English "
        + "and download an Enhanced or Premium voice. It'll be used here automatically."

    // MARK: Actions

    /// Deep-link to the app's Settings root via `openSettingsURLString`. On the
    /// macOS test slice the string constant is UIKit-gated, so this is a no-op
    /// there; in production iOS it opens Settings.
    private func openSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
        #endif
    }

    // MARK: Bindings

    private var voiceGenderBinding: Binding<VoiceGender> {
        Binding(
            get: { viewModel.voiceGender },
            set: { viewModel.voiceGender = $0 }
        )
    }
}

// MARK: - VoiceGender display labels (T-721)

extension VoiceGender {
    /// User-facing label for the Cook Mode voice picker. Kept in the feature
    /// layer (not `DODSupport`) so the domain model stays free of UI copy —
    /// mirrors how ``AppearancePreference/displayName`` lives beside its view.
    var displayName: String {
        switch self {
        case .female: return "Female"
        case .male: return "Male"
        case .unspecified: return "No Preference"
        }
    }
}
