import DODDesignSystem
import SwiftUI

/// DUT-941 — "Send Test New-Post Notification" button rendered inside
/// ``OwnerToolsPlaceholderView`` when the App target injects a real
/// `sendTestNotification` closure. Split into its own file (alongside the
/// `+Profile`, `+Bindings`, etc. pattern already used in this package) so
/// `OwnerToolsPlaceholderView.swift` stays comfortably under the SwiftLint
/// `file_length` cap.
///
/// The closure itself schedules a REAL local notification for the latest
/// post (bypassing the DUT-938 last-seen diff on purpose) through the same
/// `NotificationService` toggle + system-authorization gate real delivery
/// uses — so a tap here proves the whole chain, including `dod://` deep-link
/// routing, without waiting for the background poll a TestFlight build can't
/// trigger on demand.
struct TestNotificationButton: View {

    let sendTestNotification: () async -> Void
    /// Brief inline confirmation shown after the closure runs. `nil` (no
    /// message) until the first tap.
    @State private var confirmationMessage: String?

    var body: some View {
        VStack(spacing: DODSpacing.xs) {
            Button {
                Task {
                    await sendTestNotification()
                    confirmationMessage =
                        "Test notification scheduled. It'll arrive in a moment if notifications are enabled."
                }
            } label: {
                Text("Send Test New-Post Notification")
                    .dodFont(DODType.body)
                    .frame(maxWidth: .infinity)
            }
            .dodProminentButton()
            .tint(DODColor.burntOrange)
            .accessibilityIdentifier("daddys-tools-send-test-notification")

            if let confirmationMessage {
                Text(confirmationMessage)
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("daddys-tools-send-test-notification-confirmation")
            }
        }
        .padding(.top, DODSpacing.md)
        .padding(.horizontal, DODSpacing.md)
    }
}
