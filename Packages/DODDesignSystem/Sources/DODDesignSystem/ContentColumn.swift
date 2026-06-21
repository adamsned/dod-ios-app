import SwiftUI

/// Reading-width caps for detail content on iPad. On iPhone (compact) these
/// are no-ops — the layout stays byte-identical to what it always was; on iPad
/// (regular) they bound a content block to a comfortable centered column
/// instead of letting prose + buttons stretch edge-to-edge across the wide
/// canvas (T-804). Recipe + article detail share these so the two surfaces
/// read the same on iPad.
public enum DODContentWidth {
    /// Comfortable single-column reading width for prose + stacked detail
    /// sections (intro, buttons, ingredients, instructions). Roughly a printed
    /// page; lines much past this hurt readability on a wide iPad.
    public static let reading: CGFloat = 700

    /// Wider cap for content that deliberately uses the extra iPad width — the
    /// two-up Ingredients|Instructions band on a landscape iPad (T-804). Stays
    /// bounded so an external display / very wide canvas doesn't stretch the
    /// two columns absurdly far apart.
    public static let wide: CGFloat = 1040
}

extension View {
    /// Cap this content to a centered column on iPad (regular width class),
    /// leaving iPhone (compact) byte-identical. The block keeps its own
    /// internal leading alignment + horizontal insets; this only bounds the
    /// outer width and centers the bounded block in the available space.
    ///
    /// Mirrors the ``adaptiveListRows(horizontalSizeClass:content:)``
    /// convention — compact returns `self` unchanged so the iPhone layout +
    /// snapshots never move (T-804).
    @ViewBuilder
    public func readableContentColumn(
        _ horizontalSizeClass: UserInterfaceSizeClass?,
        maxWidth: CGFloat = DODContentWidth.reading
    ) -> some View {
        if horizontalSizeClass == .regular {
            frame(maxWidth: maxWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            self
        }
    }
}
