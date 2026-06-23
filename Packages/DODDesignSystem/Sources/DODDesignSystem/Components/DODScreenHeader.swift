import SwiftUI

/// A large screen title rendered as ordinary scrolling content, placed at the
/// top of each top-level tab's scroll view so the title scrolls up and away
/// instead of using the native `.navigationTitle` large-title minimize
/// (T-781 / DUT-87).
///
/// Uniform across Feed, Categories, Search, and Saved so every tab's header
/// behaves identically; the toolbar buttons stay pinned in the nav bar. Also
/// permanently sidesteps the iOS 26 NavigationStack large-title vanishing bug
/// (T-776 / DUT-82) by never using a native large title. `.largeTitle` bold in
/// `DODColor.labelStrong` (true black/white — DUT-263).
public struct DODScreenHeader: View {

    private let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .font(.largeTitle)
            .fontWeight(.bold)
            // DUT-263 — true black/white (`labelStrong`), not the warmer brand
            // grey/cream `label`, so every tab's large title reads identically.
            .foregroundStyle(DODColor.labelStrong)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DODSpacing.md)
            .padding(.top, DODSpacing.sm)
            .padding(.bottom, DODSpacing.xs)
            .accessibilityAddTraits(.isHeader)
    }
}

extension View {
    /// DUT-263 — reserves a navigation bar on tabs that have no natural toolbar
    /// button (Search, Settings, the empty Saved state). A NavigationStack only
    /// reserves the bar's height — and thus insets its content below it — when the
    /// bar is non-empty; with an empty bar the content rides up under the status
    /// bar, leaving those tabs' ``DODScreenHeader`` ~64pt higher than Recipes /
    /// Saved (whose real toolbar buttons keep the bar present). A single hidden
    /// 1x1 item makes the bar non-empty so every tab's title lands at the same Y.
    public func dodReservesNavBarHeight() -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityHidden(true)
            }
        }
    }
}

#Preview("Header") {
    DODScreenHeader("Recipes & Articles")
        .background(DODColor.surface)
}
