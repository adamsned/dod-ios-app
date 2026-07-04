import SwiftUI

extension View {
    /// CL-289 — a `.borderedProminent` button. Pinned to `.capsule` (CL-304):
    /// buttons are now the pill tier of the two-tier roundness rule, so we fix
    /// the system button shape to a capsule rather than the card-tier
    /// `DODRadius.standard`. Keeps the system prominent fill + padding; only the
    /// corner shape is fixed. Use in place of `.buttonStyle(.borderedProminent)`.
    /// Not for icon-only buttons.
    public func dodProminentButton() -> some View {
        buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
    }

    /// CL-289 — a `.bordered` button pinned to `.capsule` (CL-304, pill tier).
    /// Use in place of `.buttonStyle(.bordered)`. See ``dodProminentButton()``.
    public func dodBorderedButton() -> some View {
        buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
    }
}
