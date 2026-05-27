import SwiftUI

/// Hand-rolled flow layout — wraps subviews onto new rows when the proposal
/// runs out of width. Used for the chip rows in `IdleSuggestionsView`.
/// Kept private to DODFeatureSearch because it's a UX-quality helper, not
/// a general design-system component.
struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var posX = bounds.minX
        var posY = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if posX + size.width > bounds.maxX, posX > bounds.minX {
                posX = bounds.minX
                posY += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: posX, y: posY),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            posX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
