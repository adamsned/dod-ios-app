#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import UIKit
import XCTest

@testable import DODFeatureFeed

/// L4 visual-regression coverage for ``SettingsView``'s loaded state.
///
/// Two iPhone 13 baselines (light + dark, default Dynamic Type) lock the
/// US-32 / AC-32.2 layout match against the Categories tab treatment.
/// First iOS-sim test run uses `record: .missing` to lay any missing
/// baseline PNGs down.
///
/// Spec trace: US-32 AC-32.1..AC-32.4, CC-1 (light + dark accessibility).
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

    // MARK: - Fixtures

    /// Drives `SettingsView` with an isolated UserDefaults suite so the
    /// snapshot is deterministic (no shared-defaults bleed between
    /// concurrent test processes).
    @MainActor
    static func makeHostedView() -> some View {
        let suite = "SettingsViewSnapshotTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        let viewModel = SettingsViewModel(defaults: defaults)
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
