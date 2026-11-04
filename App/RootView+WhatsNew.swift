import DODAnalytics
import DODFeatureFeed
import DODNetworking
import SwiftUI

/// DUT-174 — presents the post-update changelog once per version.
struct WhatsNewPresenter: ViewModifier {
    @State private var release: ChangelogRelease?
    private let provider = WhatsNewProvider.live()

    func body(content: Content) -> some View {
        content
            .task { await evaluate() }
            .sheet(item: $release) { release in
                WhatsNewView(release: release) { self.release = nil }
                    .onAppear { Telemetry.shared.send(.changelogShown(version: release.version)) }
                    .onDisappear { Telemetry.shared.send(.changelogDismissed(version: release.version)) }
                    .presentationDetents([.medium, .large])
            }
    }

    @MainActor
    private func evaluate() async {
        let current = WhatsNewGate.currentVersion()
        // Fresh install: baseline silently, so no backlog is shown.
        WhatsNewGate.baselineIfNeeded(currentVersion: current)
        guard WhatsNewGate.shouldPresent(currentVersion: current, lastSeenVersion: WhatsNewGate.lastSeen()) else {
            return
        }
        // Mark seen BEFORE presenting so the sheet can never reappear for this version.
        WhatsNewGate.markSeen(current)
        release = await provider.release(for: current)
    }
}

extension View {
    func whatsNewOnUpdate() -> some View { modifier(WhatsNewPresenter()) }
}
