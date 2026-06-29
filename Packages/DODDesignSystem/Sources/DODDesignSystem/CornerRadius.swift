import CoreGraphics

/// Canonical corner radii (CL-286). Use these for ALL rounded rectangles —
/// buttons, cards, sheets, containers, thumbnails — so the app's roundness stays
/// consistent. Do NOT hard-code radius literals and do NOT reuse `DODSpacing`
/// values for rounding.
///
/// - ``standard`` (12pt) is the everywhere radius — it matches the system
///   inset-grouped list cells in the Settings tab, the reference roundness.
/// - ``inner`` (8pt) is the complementary smaller radius, used only where
///   ``standard`` would visually clip the content (small thumbnails, nested
///   images inside a rounded container, small pills). For a nested element the
///   concentric ideal is `outer − padding`; `inner` is the codified value that
///   reads right against a 12pt `standard`.
///
/// Fully-round shapes (`Capsule()` / `Circle()` — pills, badges, avatars) are
/// intentionally exempt; they stay fully rounded.
///
/// Plan trace: plan.md §5 (design tokens).
public enum DODRadius {
    /// The everywhere radius (12pt) — matches the Settings inset-grouped cells.
    public static let standard: CGFloat = 12
    /// Complementary smaller radius (8pt) for content the standard would clip.
    public static let inner: CGFloat = 8
}
