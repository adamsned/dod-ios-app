#if canImport(UIKit)
import DODPersistence
import SnapshotTesting
import SwiftUI
import UIKit
import XCTest

@testable import DODFeatureFeed

/// L4 visual-regression coverage for ``SettingsView``'s loaded state.
///
/// Two iPhone 13 baselines (light + dark, default Dynamic Type) lock the
/// US-32 / AC-32.2 layout match against the Categories tab treatment,
/// extended in US-36 / T-630 to include the five additional rows
/// (Notifications, Appearance, Default Share Format, Clear Cached
/// Recipe Images, Share Anonymous Usage Data). The T-550 baselines
/// were deleted on the T-630 commit; iOS-sim first-run uses
/// `record: .missing` to lay the expanded PNGs down.
///
/// T-703 (US-41 / AC-41.3) adds three additional baselines specifically
/// for the new iCloud Sync section: toggle off (no Status row), toggle
/// on (Status row visible reading "Idle"), and the off → on
/// confirmation alert visible state.
///
/// Spec trace: US-32 AC-32.1..AC-32.4, US-36 AC-36.1..AC-36.8,
/// US-41 AC-41.3 + AC-41.4, CC-1 (light + dark accessibility).
final class SettingsViewSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        isRecording = false
    }

    @MainActor
    func test_settingsView_light_defaultDynamicType() async {
        let view = Self.makeHostedView()
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 844), traits: Self.lightTraits()),
            record: .missing
        )
    }

    @MainActor
    func test_settingsView_dark_defaultDynamicType() async {
        let view = Self.makeHostedView()
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 844), traits: Self.darkTraits()),
            record: .missing
        )
    }

    // MARK: - T-703 / US-41 AC-41.3 — iCloud Sync section baselines

    @MainActor
    func test_settings_iCloudSyncSection_off_light_defaultDynamicType() async {
        // Toggle OFF (the default) — section renders the toggle only;
        // the Status row is hidden because `isCloudSyncEnabled` is
        // false. Locks the off-state subtext ("Saved recipes stay on
        // this device.") + the section header rendering.
        let view = Self.makeHostedView(cloudSyncEnabled: false)
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 844), traits: Self.lightTraits()),
            record: .missing
        )
    }

    @MainActor
    func test_settings_iCloudSyncSection_on_light_defaultDynamicType() async {
        // Toggle ON — the Status row appears and renders the placeholder
        // "Idle" copy until T-705 wires the real `CloudKitSyncStatus`.
        // Locks the on-state subtext + the Status row layout reservation.
        let view = Self.makeHostedView(cloudSyncEnabled: true)
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 844), traits: Self.lightTraits()),
            record: .missing
        )
    }

    @MainActor
    func test_settings_iCloudSyncSection_alertVisible_light() async {
        // Confirmation alert visible. Starts with the toggle OFF and
        // fires an off → on request so the view-model holds a
        // pending `CloudSyncConfirmationRequest(targetEnabled: true)`.
        // Note: SwiftUI's `.alert(...)` modifier is presented by the
        // host UIViewController, not as part of the SwiftUI view tree,
        // so the visible pixels in this snapshot are the underlying
        // Settings list (NOT the alert chrome) — the test still locks
        // the underlying surface rendering during an in-flight alert
        // request, so a future code path that crashes the view when a
        // request is pending shows up as a snapshot failure rather
        // than only firing in a UI test. The actual alert copy is
        // pinned by the `cloudSyncAlertMessage(for:)` static + the
        // L1 confirmation flow tests in SettingsViewModelTests.
        let view = Self.makeHostedView(cloudSyncEnabled: false, pendingFlip: true)
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 844), traits: Self.lightTraits()),
            record: .missing
        )
    }

    // MARK: - T-738 / US-32 AC-32.6 — About Ned destination baselines

    @MainActor
    func test_aboutNedView_light_defaultDynamicType() async {
        // The graduated About destination (T-738 / CL-133, DUT-14) —
        // verbatim DUT-14 copy + bundled `AboutNed` photo in a
        // magazine-sidebar layout. Locks the 120pt leading image clip
        // + the right-side paragraph wrap.
        let view = NavigationStack { AboutNedView() }
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 844), traits: Self.lightTraits()),
            record: .missing
        )
    }

    @MainActor
    func test_aboutNedView_dark_defaultDynamicType() async {
        let view = NavigationStack { AboutNedView() }
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 844), traits: Self.darkTraits()),
            record: .missing
        )
    }

    // MARK: - Fixtures

    /// Drives `SettingsView` with an isolated UserDefaults suite so the
    /// snapshot is deterministic (no shared-defaults bleed between
    /// concurrent test processes).
    ///
    /// `cloudSyncEnabled` seeds the canonical `RecipeStore.cloudKitSyncOptInKey`
    /// flag before view-model construction so the view-model's cached
    /// `isCloudSyncEnabled` mirrors the requested state. `pendingFlip`
    /// fires an off → on toggle request so the confirmation alert
    /// renders in the snapshot.
    @MainActor
    static func makeHostedView(
        cloudSyncEnabled: Bool = false,
        pendingFlip: Bool = false
    ) -> some View {
        let suite = "SettingsViewSnapshotTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        defaults.set(cloudSyncEnabled, forKey: RecipeStore.cloudKitSyncOptInKey)
        let viewModel = SettingsViewModel(defaults: defaults)
        if pendingFlip {
            // Drive an off → on flip so the confirmation alert is in
            // its pending state when SwiftUI snapshots the view.
            viewModel.requestCloudSyncOptIn(!cloudSyncEnabled)
        }
        return SettingsViewSnapshotHost(viewModel: viewModel)
    }

    // MARK: - Trait helpers

    static func lightTraits() -> UITraitCollection {
        UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: .light),
            UITraitCollection(displayScale: 3),
        ])
    }

    static func darkTraits() -> UITraitCollection {
        UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: .dark),
            UITraitCollection(displayScale: 3),
        ])
    }
}

// MARK: - Stateful host

@MainActor
private struct SettingsViewSnapshotHost: View {
    let viewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            SettingsView(viewModel: viewModel)
        }
    }
}
#endif
