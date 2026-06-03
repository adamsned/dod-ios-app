import DODDesignSystem
import SwiftUI

/// Popup card overlaid on the blurred Ratings & Reviews WRITE composer
/// when the user has no profile. Renders the "Set up your profile" prompt
/// + body copy + a "Set Up Profile" CTA. Tap fires the
/// ``onSetUpProfile`` callback so the host can present
/// ``ProfileEditView`` as a modal sheet OVER the recipe.
///
/// Surface is the smallest possible card the layout needs — a single
/// VStack with the SF Symbol icon, the heading, the body, and the
/// branded button. Brand styling (`DODColor.castIronBrown` fill +
/// `DODColor.cream` foreground) mirrors the brand button treatment in
/// ``WidgetCard`` + ``RecipeCard``.
///
/// Sized at `maxWidth: 320` so the card stays scannable on iPad +
/// landscape orientations without spreading the body text into an
/// unreadable single line.
///
/// **T-744 / CL-141 (DUT-38) — solid `DODColor.surface` background.**
/// The popup card uses a solid ``DODColor/surface`` background (light
/// mode `#FFFFFF`, dark mode `#1B140E` deep warm-brown — matches the
/// recipe-detail page background `DODColor.surface`) so the card reads
/// as a solid, on-brand surface instead of a washed-out grey haze.
/// **Root cause + fix.** Pre-T-744 the body composed the background
/// fill + shadow into a single `RoundedRectangle.fill(.surface).shadow(...)`
/// chain inside `.background(...)`. Applying `.shadow(...)` to a filled
/// shape inside the background renders fill + shadow into a single
/// off-screen layer; the shadow's antialiased perimeter + the rounded
/// corners' slight rendering translucency was enough for the SwiftUI
/// compositor (and the user's eye) to blend the card's interior with
/// the underlying `.ultraThinMaterial` `Rectangle` overlay (which dims
/// the blurred composer below the popup). The fix is to hoist the
/// `.shadow(...)` OUT of the `.background(...)` fill chain so the fill
/// commits to its own opaque layer first, then the shadow applies to
/// the composed card on the outside. The ZStack composition in
/// ``RecipeDetailRatingsSection/gatedRateAndReviewCard`` is preserved
/// verbatim per AC-44.10 — only the card's own background composition
/// changes.
///
/// Accessibility: the CTA carries ``accessibilityIdentifier`` so a
/// future L5 E2E journey ("set up a profile from the recipe gate") can
/// drive the flow without revisiting the view code. The card itself
/// reads as a contained accessibility group so VoiceOver announces it
/// as one coherent "Set up your profile…" element rather than three
/// separate Text rows.
///
/// Spec trace: US-44 AC-44.10 (amended T-744 / CL-141); CL-138; DUT-36 Phase c.
public struct RatingsProfileGate: View {

    let onSetUpProfile: () -> Void

    public init(onSetUpProfile: @escaping () -> Void) {
        self.onSetUpProfile = onSetUpProfile
    }

    public var body: some View {
        VStack(spacing: DODSpacing.md) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(DODColor.accent)
                .accessibilityHidden(true)

            Text("Set up your profile")
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.label)

            Text("To leave a rating and review, set up your profile in Settings.")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                onSetUpProfile()
            } label: {
                Text("Set Up Profile")
                    .dodFont(DODType.bodyEmphasized)
                    .foregroundStyle(DODColor.cream)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DODSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DODSpacing.sm, style: .continuous)
                            .fill(DODColor.castIronBrown)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("dod.ratings.gate.cta")
            .accessibilityLabel("Set Up Profile")
            .accessibilityHint("Opens profile setup. After saving, you can rate and review this recipe.")
        }
        .padding(DODSpacing.lg)
        .frame(maxWidth: 320)
        // T-744 / CL-141 (DUT-38) — `.shadow(...)` is hoisted OUT of
        // the `.background(...)` fill chain so the fill commits to its
        // own opaque layer first; the shadow then applies to the
        // composed card on the outside. This makes the card read as
        // solid even when the parent ZStack composes a translucent
        // `.ultraThinMaterial` overlay underneath the popup.
        .background(
            RoundedRectangle(cornerRadius: DODSpacing.md, style: .continuous)
                .fill(DODColor.surface)
        )
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview("RatingsProfileGate") {
    RatingsProfileGate(onSetUpProfile: {})
        .padding()
        .background(DODColor.surface)
}
