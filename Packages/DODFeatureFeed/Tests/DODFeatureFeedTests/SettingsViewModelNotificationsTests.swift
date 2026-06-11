import Foundation
import Testing

@testable import DODFeatureFeed

/// L1 coverage for the Settings notification toggle setters
/// (`SettingsViewModel+Notifications.swift`). The recipe-drop toggle's
/// persistence is covered in `SettingsViewModelTests`; this suite focuses
/// on the T-750 / CL-147 (DUT-56) "When Someone Replies to My Comment"
/// toggle — its default-off persistence + the authorization-gated enable
/// path (grant persists ON; deny reverts to OFF + surfaces a snackbar;
/// OFF never calls authorization).
///
/// Lives in its own file (not appended to `SettingsViewModelTests`) so
/// that suite stays under the SwiftLint 400-line file_length cap.
///
/// Spec trace: US-36 AC-36.1; US-42 AC-42.1; CL-147.
@MainActor
@Suite("SettingsViewModel notifications (T-750 / CL-147)")
struct SettingsViewModelNotificationsTests {

    /// Fresh isolated `UserDefaults` suite per test so persisted keys
    /// never bleed across cases (mirrors `SettingsViewModelTests`).
    static func isolatedDefaults() -> UserDefaults {
        let suiteName = "SettingsViewModelNotificationsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func commentReplyNotificationsDefaultsOffAndRoundTrips() async throws {
        let defaults = Self.isolatedDefaults()
        let viewModel = SettingsViewModel(defaults: defaults)

        // Default OFF (absent key).
        #expect(viewModel.commentReplyNotificationsEnabled == false)
        viewModel.commentReplyNotificationsEnabled = true
        #expect(defaults.bool(forKey: SettingsViewModel.commentReplyNotificationsEnabledKey) == true)

        // Persists across instances.
        let next = SettingsViewModel(defaults: defaults)
        #expect(next.commentReplyNotificationsEnabled == true)
    }

    @Test func setCommentReplyNotificationsEnabledOnGrantPersistsTrue() async throws {
        let defaults = Self.isolatedDefaults()
        // Inject an auth closure that GRANTS.
        let viewModel = SettingsViewModel(
            defaults: defaults,
            requestNotificationAuthorization: { true }
        )

        let granted = await viewModel.setCommentReplyNotificationsEnabled(true)
        #expect(granted == true)
        #expect(viewModel.commentReplyNotificationsEnabled == true)
        #expect(viewModel.snackbarMessage == nil)
    }

    @Test func setCommentReplyNotificationsEnabledOnDenyStaysOffWithSnackbar() async throws {
        let defaults = Self.isolatedDefaults()
        // Inject an auth closure that DENIES (the default, made explicit).
        let viewModel = SettingsViewModel(
            defaults: defaults,
            requestNotificationAuthorization: { false }
        )

        let granted = await viewModel.setCommentReplyNotificationsEnabled(true)
        #expect(granted == false)
        // Persisted intent stays OFF so the UI never claims it's on while
        // the OS suppresses delivery (mirrors AC-42.1).
        #expect(viewModel.commentReplyNotificationsEnabled == false)
        #expect(viewModel.snackbarMessage != nil)
    }

    @Test func setCommentReplyNotificationsEnabledOffPersistsFalseWithoutAuth() async throws {
        let defaults = Self.isolatedDefaults()
        // Seed it ON, then turn OFF — the OFF path must not call auth.
        defaults.set(true, forKey: SettingsViewModel.commentReplyNotificationsEnabledKey)
        let viewModel = SettingsViewModel(
            defaults: defaults,
            requestNotificationAuthorization: {
                Issue.record("Turning the toggle OFF must not request authorization")
                return true
            }
        )

        let result = await viewModel.setCommentReplyNotificationsEnabled(false)
        #expect(result == false)
        #expect(viewModel.commentReplyNotificationsEnabled == false)
    }
}
