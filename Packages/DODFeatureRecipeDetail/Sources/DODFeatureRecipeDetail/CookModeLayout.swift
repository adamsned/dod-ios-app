import SwiftUI

/// DUT-137 — which Cook Mode layout to use. Keyed on the horizontal size class
/// only, so Stage Manager / Split View / Slide Over resizes re-evaluate live.
enum CookModeLayout: Equatable {
    case stacked
    case twoPane

    /// Fraction of the width given to the pinned right pane (~38%).
    static let pinnedPaneFraction: CGFloat = 0.38

    static func resolve(horizontalSizeClass: UserInterfaceSizeClass?) -> CookModeLayout {
        horizontalSizeClass == .regular ? .twoPane : .stacked
    }

    /// Pinned pane width for a container width.
    static func pinnedPaneWidth(containerWidth: CGFloat) -> CGFloat {
        (containerWidth * pinnedPaneFraction).rounded()
    }
}
