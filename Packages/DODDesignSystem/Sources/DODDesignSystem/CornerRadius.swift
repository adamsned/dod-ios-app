import CoreGraphics

/// Canonical corner radii (CL-288, re-swept CL-304 / DUT-537).
///
/// Two-tier roundness rule (CL-304):
/// - **Card tier** — cards, cells, sheets, dialogs, containers, thumbnails use
///   ``standard`` (and ``inner`` for nested content). ``standard`` is calibrated
///   to the system `.insetGrouped` list cell, the reference roundness. iOS 26
///   ("Liquid Glass") made those cells noticeably rounder, so the old 12pt went
///   stale; measuring the live `.insetGrouped` corner on the iPhone 17 Pro sim
///   put the true radius at ~19–20pt, hence the bump. Re-measure this token per
///   major iOS release (render a real `.insetGrouped` card beside reference
///   strokes and pick the matching R).
/// - **Pill tier** — buttons, chips, badges, avatars, search fields are fully
///   rounded (`Capsule()` / `Circle()`) and do NOT use these tokens. Buttons
///   moved from `DODRadius.standard` to `.capsule` in CL-304.
///
/// Do NOT hard-code radius literals and do NOT reuse `DODSpacing` values for
/// rounding.
///
/// - ``standard`` (20pt) is the card-tier radius, matching the iOS 26
///   `.insetGrouped` list cells.
/// - ``inner`` (15pt) is the complementary smaller radius for content the
///   standard would visually clip (small thumbnails, nested images inside a
///   rounded container). For a nested element the concentric ideal is
///   `outer − padding`; ``inner`` keeps a ~5pt nesting delta below ``standard``
///   so a nested shape reads concentrically inside a 20pt container.
///
/// Plan trace: plan.md §5 (design tokens).
public enum DODRadius {
    /// The card-tier radius (20pt) — calibrated to the iOS 26 `.insetGrouped`
    /// list cells (CL-304). Re-measure per major iOS release.
    public static let standard: CGFloat = 20
    /// Complementary smaller radius (15pt) for content the standard would clip;
    /// sits ~5pt below ``standard`` so nested shapes read concentrically.
    public static let inner: CGFloat = 15
}
