import DODDesignSystem
import SwiftUI

/// SwiftUI `Binding` wrappers for ``SettingsView``.
///
/// Extracted from `SettingsView.swift` (DUT-307) to keep the host file under
/// the 400-line `file_length` cap, mirroring the existing `AboutNedView` /
/// `SettingsView+Voice` splits (T-738 / CL-134, DUT-14).
///
/// Each property wraps a view-model preference in a `Binding` so the Toggle /
/// Picker drives it without exposing the `@Observable` mutation directly to
/// the view layer. `internal` (the default) so `SettingsView/content` reaches
/// them across the file boundary.
extension SettingsView {

    var useMetricUnitsBinding: Binding<Bool> {
        Binding(
            get: { viewModel.useMetricUnits },
            set: { viewModel.useMetricUnits = $0 }
        )
    }

    var notificationsEnabledBinding: Binding<Bool> {
        Binding(
            get: { viewModel.notificationsEnabled },
            // Turning ON requests system authorization (US-42 / AC-42.1);
            // a denied prompt leaves the persisted flag OFF so the toggle
            // springs back. The work is async (the system prompt), so it
            // runs in a Task — the `@Observable` `notificationsEnabled`
            // write inside `setNotificationsEnabled` re-renders the toggle.
            set: { newValue in
                Task { await viewModel.setNotificationsEnabled(newValue) }
            }
        )
    }

    var commentReplyNotificationsBinding: Binding<Bool> {
        Binding(
            get: { viewModel.commentReplyNotificationsEnabled },
            // Mirrors `notificationsEnabledBinding` — turning ON requests
            // system authorization (T-750 / CL-147); a denied prompt leaves
            // the persisted flag OFF so the toggle springs back.
            set: { newValue in
                Task { await viewModel.setCommentReplyNotificationsEnabled(newValue) }
            }
        )
    }

    var appearanceBinding: Binding<AppearancePreference> {
        Binding(
            get: { viewModel.appearance },
            set: { viewModel.appearance = $0 }
        )
    }

    var temperaturePreferenceBinding: Binding<TemperaturePreference> {
        Binding(
            get: { viewModel.temperaturePreference },
            set: { viewModel.temperaturePreference = $0 }
        )
    }

    var telemetryEnabledBinding: Binding<Bool> {
        Binding(
            get: { viewModel.telemetryEnabled },
            set: { viewModel.telemetryEnabled = $0 }
        )
    }
}
