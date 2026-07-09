import SwiftUI

/// **Daddy Mode (Phase 1, cosmetic).** The standout "The Dutch Oven Daddy"
/// owner badge — a burnt-orange accent-filled `Capsule` with a `crown.fill`
/// glyph, shown only to the app owner (gated upstream by `OwnerGate` in
/// DODSupport; this component is purely presentational and renders whenever a
/// caller places it).
///
/// Deliberately a touch bolder + larger than ``ModerationBadge`` so it reads as
/// a celebratory identity marker rather than a status chip: it uses the accent
/// fill (a small-pill accent fill is allowed per the design conventions — this
/// is never a full content-card fill) with ``DODColor/labelOnAccent`` text.
///
/// Self-contained: no external state, no configuration. Combined into a single
/// accessibility element labeled "The Dutch Oven Daddy, app owner".
public struct OwnerBadge: View {

    public init() {}

    public var body: some View {
        HStack(spacing: DODSpacing.xxs) {
            Image(systemName: "crown.fill")
                .accessibilityHidden(true)
            Text("The Dutch Oven Daddy")
        }
        // A step up from ModerationBadge's `.caption`: subheadline + semibold so
        // the owner badge stands out as the standout marker it's meant to be.
        .dodFont(DODType.detail)
        .fontWeight(.semibold)
        .foregroundStyle(DODColor.labelOnAccent)
        .padding(.horizontal, DODSpacing.sm)
        .padding(.vertical, DODSpacing.xs)
        .background(Capsule().fill(DODColor.accent))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("The Dutch Oven Daddy, app owner")
    }
}

#Preview("Owner badge") {
    VStack(spacing: DODSpacing.md) {
        OwnerBadge()
        // Alongside a ModerationBadge to eyeball the intended size/weight step-up.
        ModerationBadge(kind: .posted)
    }
    .padding(DODSpacing.md)
}
