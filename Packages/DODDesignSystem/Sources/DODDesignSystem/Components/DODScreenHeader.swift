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
    /// DUT-263 — reserves the navigation bar's height on tabs that have no toolbar
    /// button (Search, Settings, the empty Saved state), so their pinned
    /// ``DODScreenHeader`` insets to the same Y as Recipes / Saved. An empty
    /// `inline` navigation title makes the bar non-empty WITHOUT adding a button:
    /// a hidden toolbar item would render as an empty Liquid-Glass capsule (visual
    /// noise), whereas an empty title is invisible. Inline (not large) also dodges
    /// the iOS 26 large-title vanish bug (DUT-82).
    public func dodReservesNavBarHeight() -> some View {
        // `navigationBarTitleDisplayMode` is iOS-only; on macOS (where the feature
        // packages' `swift test` compiles this) it doesn't exist — and reserving a
        // UINavigationBar is an iOS concept anyway — so this is a macOS no-op.
        #if os(iOS)
        return navigationTitle("").navigationBarTitleDisplayMode(.inline)
        #else
        return self
        #endif
    }
}

#Preview("Header") {
    DODScreenHeader("Recipes & Articles")
        .background(DODColor.surface)
}
