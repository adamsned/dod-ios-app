import DODDesignSystem
import SwiftUI

/// DUT-25 (TestFlight build 1.0 / 2026.0601.1159, Dani Anderson): the Search
/// screen's `DODSearchField` was "camouflaged" — it fills its capsule with
/// `DODColor.surfaceElevated`, which in light mode is `#FFFFFF`, exactly the
/// same hex as the `DODColor.surface` screen background behind it (the two
/// tokens collapse to white in light per US-43 / CL-111). With no border, the
/// field read as flat white-on-white, so only the glyph + placeholder hinted
/// at an interactive control.
///
/// This modifier gives the field a clear, tappable affordance that holds up in
/// BOTH appearances using design-system tokens only:
///
/// - A `DODColor.surfaceDivider` border (light `#E6DECF` on white, dark
///   `#3D2B1F` on `#1B140E`) — the load-bearing fix. It is drawn as an
///   `overlay` stroke so it sits ON TOP of the component's own opaque capsule
///   fill and is never masked by it, which is what guarantees the outline
///   shows in light mode where the fill is white.
/// - A `DODColor.surfaceElevated` underlay fill so the subtle filled-pill
///   convention is present in dark mode (and is a no-op match for the
///   component's own fill in light mode).
/// - A soft shadow for a touch of lift off the flat background. Rendered
///   outside the shape, so it too survives the opaque white fill.
///
/// Scoped to the Search surface (DUT-25 is the Search-tab report) rather than
/// edited into the shared `DODSearchField` in DODDesignSystem, to avoid
/// changing the Categories-tab bar and churning that module's committed
/// snapshot baselines in the same focused fix.
extension View {

    /// Wraps a `DODSearchField` with a visible border + subtle fill + soft
    /// shadow so it reads as an interactive search field on the white Search
    /// background. Apply BEFORE the surrounding screen padding so the outline
    /// hugs the capsule rather than the padded frame.
    func dodSearchFieldAffordance() -> some View {
        background(
            Capsule(style: .continuous)
                .fill(DODColor.surfaceElevated)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(DODColor.surfaceDivider, lineWidth: 1.5)
        )
        .shadow(color: DODColor.charcoal.opacity(0.08), radius: 3, x: 0, y: 1)
    }
}
