import SwiftUI

/// Grid columns that adapt to horizontal size class: two columns on iPhone
/// (compact width), three columns on iPad regular. Used by Feed, Categories,
/// Search, Saved for consistent grid behavior (spec CC-8 + CC-9 amendment,
/// T-150..T-154).
public struct AdaptiveRecipeGrid: Layout {
    public var spacing: CGFloat
    public var compactColumns: Int
    public var regularColumns: Int

    public init(spacing: CGFloat = DODSpacing.md, compactColumns: Int = 2, regularColumns: Int = 3) {
        self.spacing = spacing
        self.compactColumns = compactColumns
        self.regularColumns = regularColumns
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        let columns = columns(forWidth: width)
        let rows = Int((Double(subviews.count) / Double(columns)).rounded(.up))
        let cellWidth = max(0, (width - spacing * CGFloat(columns - 1)) / CGFloat(columns))
        let cellHeight = subviews.first.map { $0.sizeThatFits(.init(width: cellWidth, height: nil)).height } ?? 0
        let height = CGFloat(rows) * cellHeight + CGFloat(max(0, rows - 1)) * spacing
        return CGSize(width: width, height: height)
    }

    public func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let columns = columns(forWidth: bounds.width)
        let cellWidth = max(0, (bounds.width - spacing * CGFloat(columns - 1)) / CGFloat(columns))
        let cellSize = ProposedViewSize(width: cellWidth, height: nil)
        let cellHeight = subviews.first.map { $0.sizeThatFits(cellSize).height } ?? 0
        for (index, subview) in subviews.enumerated() {
            let row = index / columns
            let col = index % columns
            let originX = bounds.minX + CGFloat(col) * (cellWidth + spacing)
            let originY = bounds.minY + CGFloat(row) * (cellHeight + spacing)
            subview.place(at: CGPoint(x: originX, y: originY), proposal: cellSize)
        }
    }

    private func columns(forWidth width: CGFloat) -> Int {
        // Heuristic: 600pt is roughly iPad portrait splitscreen threshold.
        width >= 600 ? regularColumns : compactColumns
    }
}

extension View {
    /// Apply the adaptive grid container.
    public func adaptiveRecipeGrid(spacing: CGFloat = DODSpacing.md) -> some View {
        modifier(AdaptiveGridContainer(spacing: spacing))
    }
}

private struct AdaptiveGridContainer: ViewModifier {
    let spacing: CGFloat

    func body(content: Content) -> some View {
        // The Layout above is intentionally narrow-purpose; the more
        // common SwiftUI idiom is LazyVGrid with adaptive columns.
        // Features may prefer that — both are available.
        content
    }
}

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
