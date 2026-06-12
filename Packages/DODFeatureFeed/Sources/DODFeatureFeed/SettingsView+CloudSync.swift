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
        // T-760 / CL-157 (DUT-66) — ONE cell: the toggle on top, then (when
        // sync is ON) a smaller (``DODType/detail``) inline Status line,
        // folded in rather than living in its own row.
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Toggle(isOn: toggleBinding) {
                Text("iCloud Sync")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.label)
            }
            .accessibilityIdentifier("settings-toggle-icloud-sync")
            .accessibilityLabel("iCloud Sync")
            .accessibilityHint(accessibilityHint)

            if viewModel.isCloudSyncEnabled {
                statusLine
            }
        }
    }

    /// AC-41.7 status reservation. Read-only today; renders
    /// ``SettingsViewModel/cloudSyncStatusText`` which returns "Idle" until
    /// T-705 wires the real `CloudKitSyncStatus`-driven copy. T-760 / CL-157 —
    /// inline in the iCloud cell at the smaller ``DODType/detail`` size.
    @ViewBuilder
    private var statusLine: some View {
        HStack(spacing: DODSpacing.xs) {
            Text("Status:")
                .dodFont(DODType.detail)
                .foregroundStyle(DODColor.labelSecondary)
            Text(viewModel.cloudSyncStatusText)
                .dodFont(DODType.detail)
                .foregroundStyle(DODColor.labelSecondary)
            Spacer(minLength: 0)
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
