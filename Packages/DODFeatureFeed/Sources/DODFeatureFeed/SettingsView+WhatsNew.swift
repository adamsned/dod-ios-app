import DODAnalytics
import DODDesignSystem
import DODNetworking
import SwiftUI

/// DUT-174 — pushed from Settings; loads releases via WhatsNewProvider and lists them newest-first.
struct WhatsNewHistoryView: View {
    let provider: WhatsNewProvider
    @State private var releases: [ChangelogRelease] = []

    /// Returns the first (latest) release or nil if the array is empty.
    static func latest(_ releases: [ChangelogRelease]) -> ChangelogRelease? {
        releases.first
    }

    var body: some View {
        List(releases) { release in
            NavigationLink(release.title) {
                WhatsNewView(release: release, onDismiss: {})
            }
            .dodFont(DODType.body)
        }
        .navigationTitle("What's New")
        .task {
            Telemetry.shared.send(.changelogOpenedFromSettings)
            releases = await provider.releases()
        }
        .accessibilityIdentifier("whats-new-history")
    }
}

extension SettingsView {
    @ViewBuilder
    var whatsNewLink: some View {
        NavigationLink {
            WhatsNewHistoryView(provider: .live())
        } label: {
            Text("What's New").dodFont(DODType.body).foregroundStyle(DODColor.label)
        }
        .accessibilityIdentifier("settings-link-whats-new")
    }
}
