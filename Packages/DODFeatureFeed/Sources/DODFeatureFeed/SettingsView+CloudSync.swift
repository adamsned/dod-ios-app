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

// MARK: - Confirmation dialog (T-757 / CL-154, DUT-63)

extension View {
    /// Fronts every iCloud Sync toggle flip per CL-89 with a custom
    /// branded confirmation dialog (replaces the pre-T-757 system
    /// `.alert`). **Why custom, not `.alert`:** (1) system alert buttons
    /// inherit the app's `.tint(DODColor.accent)` (orange) and Apple
    /// gives no per-button foreground override, so white button text was
    /// impossible; (2) the system `.alert`'s `isPresented` binding fired
    /// `cancelCloudSyncFlip()` on dismiss, which raced + reverted the
    /// async `confirmCloudSyncFlip()` so the toggle never flipped. The
    /// custom dialog is driven purely by `cloudSyncConfirmationRequest`
    /// (no `isPresented` binding → no cancel-on-dismiss race) and styles
    /// its own buttons. The view-model flow is unchanged.
    func cloudSyncConfirmationAlert(viewModel: SettingsViewModel) -> some View {
        modifier(CloudSyncConfirmationDialogModifier(viewModel: viewModel))
    }
}

/// Presents ``CloudSyncConfirmationDialog`` as a centered overlay when the
/// view-model holds a pending ``CloudSyncConfirmationRequest``.
struct CloudSyncConfirmationDialogModifier: ViewModifier {
    @Bindable var viewModel: SettingsViewModel

    func body(content: Content) -> some View {
        content
            .overlay {
                if let request = viewModel.cloudSyncConfirmationRequest {
                    CloudSyncConfirmationDialog(
                        request: request,
                        // confirm/cancel route through the unchanged VM
                        // methods. No `isPresented` binding exists, so the
                        // dismiss-cancel race that swallowed the flip is gone.
                        onConfirm: { Task { await viewModel.confirmCloudSyncFlip() } },
                        onCancel: { viewModel.cancelCloudSyncFlip() }
                    )
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: viewModel.cloudSyncConfirmationRequest)
    }
}

/// AC-41.3 / CL-89 branded confirmation dialog (T-757 / CL-154). A dimmed
/// backdrop + a centered ``DODColor/surface`` card with the direction-aware
/// title + body copy + a filled brand primary button (cream text on
/// `DODColor.castIronBrown` — the fix for the orange-button complaint) and
/// a plain Cancel. Tapping the backdrop cancels.
struct CloudSyncConfirmationDialog: View {
    let request: CloudSyncConfirmationRequest
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }
                .accessibilityHidden(true)

            VStack(spacing: DODSpacing.md) {
                Text(title)
                    .dodFont(DODType.heading)
                    .foregroundStyle(DODColor.label)
                    .multilineTextAlignment(.center)

                Text(message)
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.labelSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: DODSpacing.sm) {
                    Button(action: onConfirm) {
                        Text(confirmLabel)
                            .dodFont(DODType.bodyEmphasized)
                            .foregroundStyle(DODColor.cream)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DODSpacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: DODSpacing.sm, style: .continuous)
                                    .fill(DODColor.castIronBrown)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings-icloud-sync-alert-confirm")

                    Button(action: onCancel) {
                        Text("Cancel")
                            .dodFont(DODType.body)
                            .foregroundStyle(DODColor.label)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DODSpacing.xs)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings-icloud-sync-alert-cancel")
                }
            }
            .padding(DODSpacing.lg)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: DODSpacing.md, style: .continuous)
                    .fill(DODColor.surface)
            )
            .shadow(color: .black.opacity(0.2), radius: 16, y: 6)
            .padding(DODSpacing.lg)
            .accessibilityElement(children: .contain)
        }
    }

    private var title: String {
        request.targetEnabled ? "Turn on iCloud Sync?" : "Turn off iCloud Sync?"
    }

    private var confirmLabel: String {
        request.targetEnabled ? "Turn On" : "Turn Off"
    }

    private var message: String {
        if request.targetEnabled {
            return "Your saved recipes will sync across the Apple devices signed into the same "
                + "iCloud account. You can turn this off any time."
        }
        return "Saved recipes already on iCloud stay there. New saves will live only on this "
            + "device until you turn sync back on."
    }
}
