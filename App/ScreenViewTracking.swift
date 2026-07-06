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

    /// DUT-618 — the last tab we actually emitted `screen_view` for. `phoneTabs`
    /// and `iPadSplit` BOTH apply this modifier and swap at the size-class
    /// boundary; a pure layout flip (e.g. an iPad rotate, or a Split View resize
    /// crossing the compact/regular threshold) tears down one branch and mounts
    /// the other, re-firing `.onAppear` for the tab that was already visible —
    /// double-counting a `screen_view` no human navigation produced. Deduping on
    /// the last-emitted tab makes the layout swap a no-op while a genuine tab
    /// change still emits (the new tab differs from the last one recorded).
    @State private var lastEmittedTab: AppTab?

    func body(content: Content) -> some View {
        content
            .onChange(of: selectedTab) { _, newValue in
                emitIfChanged(newValue)
            }
            .onAppear {
                // Cold-launch emit for the initially-selected tab (Feed by
                // default). `.onChange` alone would never fire for the launch
                // screen — that omission was the DUT-256 iPad undercount. Guarded
                // by `emitIfChanged` so a size-class layout swap that re-mounts
                // this modifier doesn't re-emit for the already-visible tab.
                emitIfChanged(selectedTab)
            }
    }

    /// Emit `screen_view` for `tab` only when it differs from the last tab we
    /// emitted for, then record it. Suppresses the duplicate a layout swap would
    /// otherwise produce (DUT-618) without changing what a real tab change emits.
    private func emitIfChanged(_ tab: AppTab) {
        guard lastEmittedTab != tab else { return }
        lastEmittedTab = tab
        Self.emitScreenView(for: tab)
    }

    /// Send the `screen_view` event for `tab`. Both the on-appear (cold-launch)
    /// and on-change emits route through here so the two are identical and the
    /// launch-time emit is verifiable without a SwiftUI host (DUT-256).
    static func emitScreenView(for tab: AppTab) {
        Telemetry.shared.send(.screenView(name: tab.telemetryName))
    }
}
