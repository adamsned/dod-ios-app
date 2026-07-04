import DODAnalytics
import SwiftUI

/// Emits `screen_view` telemetry for the top-level shell's selected tab —
/// once on appear (the cold-launch view) and again on every tab change.
///
/// DUT-256 — the iPhone `TabView` path and the iPad `NavigationSplitView` path
/// had **separate, hand-copied** `.onChange` + `.onAppear` emitters, and the
/// iPad branch was originally missing the `.onAppear` initial emit, so an iPad
/// cold launch that stayed on the default Feed tab reported **no**
/// `screen_view(feed)` — undercounting iPad Feed views. DUT-318 patched the
/// missing iPad `.onAppear`, but left the two branches duplicated and free to
/// drift again. Folding both into this one modifier (applied by `phoneTabs`
/// *and* `iPadSplit`) makes the cold-launch emit structurally identical on both
/// layouts and impossible to omit on one.
struct ScreenViewTracking: ViewModifier {

    let selectedTab: AppTab

    func body(content: Content) -> some View {
        content
            .onChange(of: selectedTab) { _, newValue in
                Self.emitScreenView(for: newValue)
            }
            .onAppear {
                // Cold-launch emit for the initially-selected tab (Feed by
                // default). `.onChange` alone would never fire for the launch
                // screen — that omission was the DUT-256 iPad undercount.
                Self.emitScreenView(for: selectedTab)
            }
    }

    /// Send the `screen_view` event for `tab`. Both the on-appear (cold-launch)
    /// and on-change emits route through here so the two are identical and the
    /// launch-time emit is verifiable without a SwiftUI host (DUT-256).
    static func emitScreenView(for tab: AppTab) {
        Telemetry.shared.send(.screenView(name: tab.telemetryName))
    }
}
