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
    /// US-43 Phase c (T-712) — when true, the ``DODBrandMark`` emblem (44pt) sits
    /// on the leading edge of the header row, before the section title, as the
    /// magazine masthead. A single clean row: emblem + "Recipes & Articles" title
    /// + trailing actions. Defaults `false` so every other tab's header (and its
    /// L4 baseline) renders byte-identical; only the Feed opts in, gated by
    /// ``DODFeed/layoutVariantStorageKey``.
    private let showsBrandMark: Bool

    public init(_ title: String, showsBrandMark: Bool = false, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.showsBrandMark = showsBrandMark
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .center, spacing: DODSpacing.sm) {
            if showsBrandMark {
                // 44pt so the mark reads as an intentional element beside the
                // large title (the too-small 32pt first cut looked cramped), with
                // a little extra trailing air before the title.
                DODBrandMark(size: 44)
                    .padding(.trailing, DODSpacing.xxs)
            }
            titleText
            trailing
        }
        .padding(.horizontal, DODSpacing.md)
        .padding(.top, DODSpacing.sm)
        .padding(.bottom, DODSpacing.xs)
    }

    /// The large section title. DUT-263 — true black/white (`labelStrong`), not
    /// the warmer brand grey/cream `label`, so every tab's large title reads
    /// identically.
    private var titleText: some View {
        Text(title)
            .font(.largeTitle)
            .fontWeight(.bold)
            .foregroundStyle(DODColor.labelStrong)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

extension DODScreenHeader where Trailing == EmptyView {
    /// Title-only header (Search, Settings, Saved) — no trailing button.
    public init(_ title: String, showsBrandMark: Bool = false) {
        self.init(title, showsBrandMark: showsBrandMark) { EmptyView() }
    }
}

extension View {
    /// DUT-275 — hides the navigation bar so the tab's pinned ``DODScreenHeader``
    /// (with its inline action button) sits at the very top, at the same Y on
    /// every tab. iOS-only: the `.navigationBar` toolbar placement doesn't exist
    /// on macOS (where the feature packages' `swift test` compiles this), so this
    /// is a macOS no-op. Wrapping the `#if` here keeps call-site chains clean.
    public func dodHidesNavBar() -> some View {
        modifier(DODHidesNavBarModifier())
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
        // Magazine masthead (US-43 Phase c): emblem + wordmark above the title.
        DODScreenHeader("Recipes & Articles", showsBrandMark: true) {
            Image(systemName: "magnifyingglass").foregroundStyle(DODColor.burntOrange)
        }
        DODScreenHeader("Recipes & Articles") {
            Image(systemName: "frying.pan.fill").foregroundStyle(DODColor.burntOrange)
        }
        DODScreenHeader("Search")
    }
    .background(DODColor.surface)
}

// DUT-300 — hide the nav bar ONLY in a compact-width window. On a regular-width
// iPad the tab roots are the detail column of `RootView`'s `NavigationSplitView`,
// whose nav bar carries the sidebar-reveal toggle in portrait; blanket-hiding it
// left the user with no on-screen way to bring the sidebar (Profile + tabs) back.
// In regular width we keep the bar but collapse its title band (empty inline
// title) so the pinned `DODScreenHeader` still sits high.
private struct DODHidesNavBarModifier: ViewModifier {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS)
        if horizontalSizeClass == .regular {
            content
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
        } else {
            content.toolbar(.hidden, for: .navigationBar)
        }
        #else
        content
        #endif
    }
}
