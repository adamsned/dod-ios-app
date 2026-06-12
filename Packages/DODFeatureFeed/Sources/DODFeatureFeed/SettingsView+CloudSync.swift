import DODDesignSystem
import SwiftUI

// US-41 / AC-41.3 — iCloud Sync section rows.
//
// Extracted from `SettingsView.swift` for file_length hygiene. `CloudSyncRows`
// takes the view-model as a constructor parameter (the host's `@State` is
// `private` + not reachable from a sibling file). T-752 / CL-149 renamed
// `CloudSyncSection` → `CloudSyncRows` (rows, not a Section) so the parent
// "Data & Privacy" section composes it. T-759 / CL-156 removed the per-toggle
// confirmation dialog — the toggle now flips directly via
// `SettingsViewModel.setCloudSyncEnabled(_:)`.
//
// Spec trace: US-41 AC-41.3 + AC-41.4 + AC-41.10; CL-156 (direct flip).

// MARK: - Section rows

/// Renders the iCloud Sync ROWS the parent "Data & Privacy" section
/// composes in `SettingsView`. Two rows max: a toggle (always) + a Status
/// row (only when sync is ON — T-705 wires its real copy).
///
/// **T-752 / CL-149 (DUT-58) — rows, not a Section.** Pre-T-752 this
/// rendered its own headerless `Section` + a state-description footer
/// (T-750 / CL-147). It now provides loose rows so the parent "Data &
/// Privacy" section can compose the iCloud toggle alongside Clear Cache +
/// telemetry under one header (SwiftUI `Section`s can't share a header).
/// The state description folds into that section's footer; the
/// state-dependent `accessibilityHint` is retained on the toggle for
/// VoiceOver. The `.listRowBackground` lives on the parent section now.
struct CloudSyncRows: View {

    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Group {
            Toggle(isOn: toggleBinding) {
                Text("iCloud Sync")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.label)
            }
            .accessibilityIdentifier("settings-toggle-icloud-sync")
            .accessibilityLabel("iCloud Sync")
            .accessibilityHint(accessibilityHint)

            if viewModel.isCloudSyncEnabled {
                statusRow
            }
        }
    }

    /// AC-41.7 status row reservation. Read-only today; renders
    /// ``SettingsViewModel/cloudSyncStatusText`` which returns "Idle"
    /// until T-705 wires the real `CloudKitSyncStatus`-driven copy.
    @ViewBuilder
    private var statusRow: some View {
        HStack {
            Text("Status")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
            Spacer()
            Text(viewModel.cloudSyncStatusText)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("settings-icloud-sync-status")
    }

    /// AC-41.10 — VoiceOver hint flips with state.
    private var accessibilityHint: String {
        if viewModel.isCloudSyncEnabled {
            return "Turn off to stop syncing your saved recipes across devices."
        }
        return "Turn on to sync your saved recipes across your Apple devices."
    }

    /// Binding adapter for the row's `Toggle`. T-759 / CL-156 (DUT-65) —
    /// flips the sync DIRECTLY via ``SettingsViewModel/setCloudSyncEnabled(_:)``
    /// (no confirmation popup; the method is a no-op on an unchanged value).
    private var toggleBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isCloudSyncEnabled },
            set: { newValue in viewModel.setCloudSyncEnabled(newValue) }
        )
    }
}
