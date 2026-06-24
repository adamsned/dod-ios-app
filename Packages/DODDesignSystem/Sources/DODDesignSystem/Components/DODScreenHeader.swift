import SwiftUI

/// A large screen title pinned at the very top of each top-level tab, with an
/// optional trailing action button on the SAME row (e.g. Feed's Cooking Tools
/// menu, Saved's cart). DUT-275 — the title + its button live here in the
/// content (the nav bar is hidden), so the title sits at the same high Y on
/// EVERY tab regardless of whether it has a button: a nav-bar button would
/// reserve bar height and push that tab's title ~48pt lower than the
/// button-less tabs. Never a native `.navigationTitle` (dodges the iOS 26
/// large-title vanish bug, DUT-82). `.largeTitle` bold in `DODColor.labelStrong`
/// (true black/white — DUT-263).
public struct DODScreenHeader<Trailing: View>: View {

    private let title: String
    private let trailing: Trailing

    public init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .center, spacing: DODSpacing.sm) {
            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
                // DUT-263 — true black/white (`labelStrong`), not the warmer brand
                // grey/cream `label`, so every tab's large title reads identically.
                .foregroundStyle(DODColor.labelStrong)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            trailing
        }
        .padding(.horizontal, DODSpacing.md)
        .padding(.top, DODSpacing.sm)
        .padding(.bottom, DODSpacing.xs)
    }
}

extension DODScreenHeader where Trailing == EmptyView {
    /// Title-only header (Search, Settings, Saved) — no trailing button.
    public init(_ title: String) {
        self.init(title) { EmptyView() }
    }
}

extension View {
    /// DUT-275 — hides the navigation bar so the tab's pinned ``DODScreenHeader``
    /// (with its inline action button) sits at the very top, at the same Y on
    /// every tab. iOS-only: the `.navigationBar` toolbar placement doesn't exist
    /// on macOS (where the feature packages' `swift test` compiles this), so this
    /// is a macOS no-op. Wrapping the `#if` here keeps call-site chains clean.
    public func dodHidesNavBar() -> some View {
        #if os(iOS)
        return toolbar(.hidden, for: .navigationBar)
        #else
        return self
        #endif
    }

    /// CL-265 — inline navigation-bar title display mode. iOS-only (the API
    /// doesn't exist on macOS, where the feature packages' `swift test`
    /// compiles this), so this is a macOS no-op. Pairs with an empty
    /// `navigationTitle("")` to keep a sheet's nav bar minimal (just its
    /// toolbar buttons) beneath an in-content header. Wrapping the `#if` here
    /// keeps call-site chains clean for swift-format.
    public func dodInlineNavTitle() -> some View {
        #if os(iOS)
        return navigationBarTitleDisplayMode(.inline)
        #else
        return self
        #endif
    }
}

#Preview("Header") {
    VStack(spacing: 0) {
        DODScreenHeader("Recipes & Articles") {
            Image(systemName: "frying.pan.fill").foregroundStyle(DODColor.burntOrange)
        }
        DODScreenHeader("Search")
    }
    .background(DODColor.surface)
}
