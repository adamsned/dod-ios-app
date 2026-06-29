import SwiftUI

extension View {
    /// CL-289 — a `.borderedProminent` button pinned to the canonical
    /// `DODRadius.standard` corner. iOS otherwise picks its own button radius, so
    /// without this, system buttons wouldn't obey the CL-288 radius rule. Keeps
    /// the system prominent fill + padding; only the corner shape is fixed. Use
    /// in place of `.buttonStyle(.borderedProminent)`. Not for icon-only buttons.
    public func dodProminentButton() -> some View {
        buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: DODRadius.standard))
    }

    /// CL-289 — a `.bordered` button pinned to `DODRadius.standard`. Use in place
    /// of `.buttonStyle(.bordered)`. See ``dodProminentButton()``.
    public func dodBorderedButton() -> some View {
        buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: DODRadius.standard))
    }
}
