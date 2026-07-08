import DODDesignSystem
import DODSupport
import SwiftUI

// US-40 / AC-40.12 (DUT-332 / DUT-334) — the Settings → Cook Mode Voice rows.
//
// CL-279 / DUT-329 — Cook Mode uses ONE auto-selected voice; there is no in-app
// voice or gender choice. DUT-332 names the resolved voice + previews it;
// DUT-334 — where to download voices is stated in the section footer (in
// SettingsView.swift), not a popup. Extracted from SettingsView.swift so that
// file stays under the SwiftLint file_length cap. `VoiceRows` takes the
// view-model as a constructor parameter (like `CloudSyncRows`).

/// Renders the Cook Mode Voice cell: the resolved voice name + quality
/// ("Voice: Jamie (Premium)") with a trailing speaker button that previews it.
struct VoiceRows: View {

    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DODSpacing.sm) {
            VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                Text("Cook Mode Voice")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.label)
                Text(viewModel.resolvedVoiceDisplay)
                    .dodFont(DODType.detail)
                    .foregroundStyle(DODColor.labelSecondary)
                    .accessibilityIdentifier("settings-voice-quality")
            }
            Spacer()
            Button {
                viewModel.previewVoice()
            } label: {
                Image(systemName: "speaker.wave.2")
                    .foregroundStyle(DODColor.accent)
                    .frame(minWidth: 44, minHeight: 44)  // DUT-694: 44pt tap target
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings-voice-preview")
            .accessibilityLabel("Preview voice")
        }
    }
}
