import SwiftUI

/// A large screen title rendered as ordinary scrolling content, placed at the
/// top of each top-level tab's scroll view so the title scrolls up and away
/// instead of using the native `.navigationTitle` large-title minimize
/// (T-781 / DUT-87).
///
/// Uniform across Feed, Categories, Search, and Saved so every tab's header
/// behaves identically; the toolbar buttons stay pinned in the nav bar. Also
/// permanently sidesteps the iOS 26 NavigationStack large-title vanishing bug
/// (T-776 / DUT-82) by never using a native large title. Matches the styling of
/// the former per-tab manual "Saved" header (`.largeTitle` bold, `DODColor.label`).
public struct DODScreenHeader: View {

    private let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .font(.largeTitle)
            .fontWeight(.bold)
            .foregroundStyle(DODColor.label)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DODSpacing.md)
            .padding(.top, DODSpacing.sm)
            .padding(.bottom, DODSpacing.xs)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview("Header") {
    DODScreenHeader("Recipes & Articles")
        .background(DODColor.surface)
}
