import DODSupport

// Its own file because RootView+LinkRouting.swift is at SwiftLint's 400-line cap.
extension RootView {
    /// DUT-989 — the Control Center "Tonight's Rung" tap. Reads the published
    /// snapshot and opens Cook Mode for that recipe through the existing
    /// `handle(intent:)` (`.startCookMode`). With no snapshot yet, falls back to
    /// the Cook Mode hub tool so the tap never dead-ends.
    func routeToTonightsRung() {
        guard let snapshot = WidgetSnapshotStore()?.readTonightsRung() else {
            route(toHubTool: .cookMode)
            return
        }
        handle(intent: snapshot.deepLinkIntent)
    }
}
