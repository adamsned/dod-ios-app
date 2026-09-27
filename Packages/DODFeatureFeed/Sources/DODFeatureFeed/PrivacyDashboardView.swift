import DODDesignSystem
import SwiftUI

/// DUT-160 — the "Privacy Dashboard: Where your data lives" screen, pushed from
/// Settings ▸ Data & Privacy. Read-only + informational: it groups the user's
/// data into three location buckets (On Device, iCloud Private, Public Blog),
/// each row a Title-Case category with a one-tap plain-language explanation, and
/// deep-links out to the existing controls (it never duplicates them).
///
/// Styling matches the other Settings sub-screens (`.insetGrouped` List over
/// `DODColor.surface`, `DODColor.surfaceElevated` rows, `DODType.heading`
/// section headers). Counts are live from `DODPersistence` via the
/// ``SettingsDependencies`` seam; the row cell + per-bucket footer deep-links
/// live in `PrivacyDashboardView+Rows.swift` to keep this file under the
/// SwiftLint 400-line `file_length` cap.
struct PrivacyDashboardView: View {

    /// The Settings view-model, for the dependency seam + the profile-presence
    /// and iCloud-sync flags the inventory needs.
    @Bindable var settings: SettingsViewModel

    /// Closes the whole Settings sheet, so a cross-tab deep link (Shopping List,
    /// Saved) reveals its destination instead of leaving the sheet on top.
    /// Injected from `SettingsView` (which owns the sheet's dismiss).
    let onCloseSettings: () -> Void

    /// Assembles the buckets from the live inventory (loaded on appear).
    @State private var model = PrivacyDashboardViewModel()

    /// Rows whose plain-language explanation is currently expanded (one-tap).
    @State private var expandedRowIDs: Set<String> = []

    /// Routes `dod://` deep links through the app's tree-wide `openURL` override.
    @Environment(\.openURL) private var openURL
    /// Pops back to the Settings list (where the iCloud Sync toggle + Clear
    /// Cache controls live), for the iCloud bucket's "Manage" action.
    @Environment(\.dismiss) var popToSettings

    var body: some View {
        let list = List {
            introSection
            ForEach(model.buckets) { bucket in
                bucketSection(bucket)
            }
        }
        .scrollContentBackground(.hidden)
        .background(DODColor.surface)
        .navigationTitle("Privacy Dashboard")
        .dodInlineNavTitle()
        .accessibilityIdentifier("privacy-dashboard")
        .task {
            await model.load(
                from: settings.cloudSyncDependency,
                hasProfile: settings.profile != nil,
                iCloudSyncOn: settings.isCloudSyncEnabled
            )
        }

        #if os(iOS)
        list.listStyle(.insetGrouped)
        #else
        list
        #endif
    }

    // MARK: - Intro

    /// A short sentence-case lead so the screen reads as an explanation, not a
    /// control panel.
    private var introSection: some View {
        Section {
            Text("Here is where each kind of your data lives. Tap a row for a plain-language explanation.")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .listRowBackground(DODColor.surfaceElevated)
    }

    // MARK: - Bucket section

    /// One titled bucket: a `DODType.heading` header, a sentence-case summary
    /// footer, the category rows, and the bucket's deep-link controls.
    @ViewBuilder
    private func bucketSection(_ bucket: PrivacyBucket) -> some View {
        Section {
            ForEach(bucket.rows) { row in
                dataRow(row)
            }
            bucketControls(bucket)
        } header: {
            Text(bucket.title)
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.label)
        } footer: {
            Text(bucket.summary)
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .listRowBackground(DODColor.surfaceElevated)
    }

    // MARK: - Expansion state

    /// Toggle a row's one-tap explanation open/closed.
    func toggleExpanded(_ id: String) {
        if expandedRowIDs.contains(id) {
            expandedRowIDs.remove(id)
        } else {
            expandedRowIDs.insert(id)
        }
    }

    func isExpanded(_ id: String) -> Bool {
        expandedRowIDs.contains(id)
    }

    // MARK: - Deep-link helpers

    /// Open an in-app `dod://` route, then close Settings so the destination is
    /// visible (mirrors the FirstCookout `openURL(url); dismiss()` hand-off).
    func openRoute(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        openURL(url)
        onCloseSettings()
    }
}
