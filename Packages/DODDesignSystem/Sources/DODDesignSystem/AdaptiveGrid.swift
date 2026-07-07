import SwiftUI

/// Convenience: standard adaptive `LazyVGrid` columns for recipe rows.
///
/// Rationale (CC-9 amendment, May 2026): the original 1-column / 2-column
/// split made the feed feel sparse on modern iPhone hardware — only ~2
/// cards visible above the tab bar on an iPhone 17. Bumping compact to 2
/// columns and regular to 3 columns gives a denser, more contemporary
/// browsing surface (3+ rows above the fold on iPhone 13 baseline) while
/// still keeping each card wide enough (~180pt) to read the title and
/// excerpt comfortably.
public func recipeGridColumns(horizontalSizeClass: UserInterfaceSizeClass?) -> [GridItem] {
    let columns = horizontalSizeClass == .regular ? 3 : 2
    return Array(
        repeating: GridItem(.flexible(), spacing: DODSpacing.md, alignment: .top),
        count: columns
    )
}

/// Columns for the dense LIST layout (`RecipeCard.ListRow` rows): a single
/// column on iPhone (compact) and two columns on iPad (regular) so the rows
/// tile across the wider canvas instead of stretching into one blown-up
/// column (T-782 / DUT-88). List rows are wider than gallery cards, so the
/// list uses two columns where the gallery (``recipeGridColumns``) uses three.
public func recipeListColumns(horizontalSizeClass: UserInterfaceSizeClass?) -> [GridItem] {
    let columns = horizontalSizeClass == .regular ? 2 : 1
    return Array(
        repeating: GridItem(.flexible(), spacing: DODSpacing.md, alignment: .top),
        count: columns
    )
}

/// Container for the dense LIST layout. Keeps iPhone (compact) on the exact
/// single-column `LazyVStack` it always used — byte-identical, so the iPhone
/// layout + snapshots stay untouched — while tiling the same rows into a
/// multi-column `LazyVGrid` on iPad (regular) via ``recipeListColumns``.
/// Callers supply the `ForEach` of `RecipeCard.ListRow` rows in `content`, so
/// each host keeps its own identifiers / tap / context-menu wiring (T-782 /
/// DUT-88). Shared by Feed + Search (title tier + ingredient tier).
@ViewBuilder
public func adaptiveListRows<Content: View>(
    horizontalSizeClass: UserInterfaceSizeClass?,
    @ViewBuilder content: () -> Content
) -> some View {
    if horizontalSizeClass == .regular {
        LazyVGrid(
            columns: recipeListColumns(horizontalSizeClass: horizontalSizeClass),
            spacing: DODSpacing.xs,
            content: content
        )
    } else {
        LazyVStack(spacing: DODSpacing.xs, content: content)
    }
}
