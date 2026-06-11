import DODDesignSystem
import SwiftUI

// US-41 / AC-41.3 — iCloud Sync section + confirmation alert plumbing.
//
// Extracted from `SettingsView.swift` so that file stays under the
// SwiftLint 400-line file_length + 250-line type_body_length caps.
// The split is mechanical — all helpers here read the same
// `SettingsViewModel` instance the host view holds via `@State`, so a
// sub-view (`CloudSyncRows`) takes the view-model as a constructor
// parameter rather than reaching for the host's `@State` (which is
// `private` and not accessible from a sibling file). The
// `cloudSyncConfirmationAlert(viewModel:)` modifier exposes the
// `.alert(...)` chain so the host's `body` stays one short call.
// T-752 / CL-149 renamed `CloudSyncSection` → `CloudSyncRows` (rows, not
// a Section) so the parent "Data & Privacy" section composes it.
//
// Spec trace: US-41 AC-41.3 + AC-41.4 + AC-41.10; CL-89 (opt-in flow +
// confirmation alerts).

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

    /// Binding adapter for the row's `Toggle`. Reads the cached
    /// `isCloudSyncEnabled` and routes any write through
    /// `requestCloudSyncOptIn(_:)` so the confirmation alert can
    /// front the flip per CL-89.
    private var toggleBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isCloudSyncEnabled },
            set: { newValue in
                // Skip no-op flips (the binding may fire twice on
                // some SwiftUI versions when the cached state mirrors
                // the new value — guard against showing a spurious
                // alert).
                guard newValue != viewModel.isCloudSyncEnabled else { return }
                viewModel.requestCloudSyncOptIn(newValue)
            }
        )
    }
}

// MARK: - Confirmation alert modifier

extension View {
    /// Attaches the `.alert(...)` modifier that fronts every iCloud
    /// Sync toggle flip per CL-89. Title + button labels + body copy
    /// flip on the direction of the pending request — off → on shows
    /// the friendly "Turn on iCloud Sync?" alert with a default "Turn
    /// On" primary, on → off shows the lighter-but-still-confirmed
    /// "Turn off iCloud Sync?" alert with a destructive "Turn Off"
    /// primary.
    func cloudSyncConfirmationAlert(viewModel: SettingsViewModel) -> some View {
        modifier(CloudSyncConfirmationAlertModifier(viewModel: viewModel))
    }
}

/// AC-41.3 / CL-89 confirmation alert payload. Reads
/// `viewModel.cloudSyncConfirmationRequest`; renders different copy +
/// button styles per flip direction.
struct CloudSyncConfirmationAlertModifier: ViewModifier {
    @Bindable var viewModel: SettingsViewModel

    func body(content: Content) -> some View {
        content
            .alert(
                title,
                isPresented: isPresented,
                presenting: viewModel.cloudSyncConfirmationRequest
            ) { request in
                buttons(for: request)
            } message: { request in
                Text(Self.message(for: request))
            }
    }

    /// Title for the confirmation alert. Reads the pending request's
    /// direction; when no request is pending the alert isn't shown so
    /// the empty-string fallback is unreachable in production.
    private var title: String {
        guard let request = viewModel.cloudSyncConfirmationRequest else { return "" }
        return request.targetEnabled ? "Turn on iCloud Sync?" : "Turn off iCloud Sync?"
    }

    /// Static so it composes inside the `.alert(message:)` closure
    /// without capturing `self`. Picks copy by direction per CL-89.
    static func message(for request: CloudSyncConfirmationRequest) -> String {
        if request.targetEnabled {
            return
                "Your saved recipes will sync across the Apple devices signed into the same iCloud account. "
                + "You can turn this off any time."
        }
        return
            "Saved recipes already on iCloud stay there. New saves will live only on this device until you turn sync back on."
    }

    /// Alert buttons for both flip directions.
    @ViewBuilder
    private func buttons(for request: CloudSyncConfirmationRequest) -> some View {
        if request.targetEnabled {
            Button("Turn On") {
                Task { await viewModel.confirmCloudSyncFlip() }
            }
            .accessibilityIdentifier("settings-icloud-sync-alert-confirm")
        } else {
            Button("Turn Off", role: .destructive) {
                Task { await viewModel.confirmCloudSyncFlip() }
            }
            .accessibilityIdentifier("settings-icloud-sync-alert-confirm")
        }
        Button("Cancel", role: .cancel) {
            viewModel.cancelCloudSyncFlip()
        }
        .accessibilityIdentifier("settings-icloud-sync-alert-cancel")
    }

    /// `isPresented` adapter for the `.alert(...)` modifier. Tracks
    /// whether the view-model has a pending confirmation request and
    /// clears it via ``SettingsViewModel/cancelCloudSyncFlip()`` when
    /// the alert dismisses without an explicit button tap (e.g. the
    /// user backgrounds the app).
    private var isPresented: Binding<Bool> {
        Binding(
            get: { viewModel.cloudSyncConfirmationRequest != nil },
            set: { newValue in
                if !newValue && viewModel.cloudSyncConfirmationRequest != nil {
                    viewModel.cancelCloudSyncFlip()
                }
            }
        )
    }
}
