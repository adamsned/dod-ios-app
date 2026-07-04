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
/// as a solid, on-brand surface. `.shadow(...)` is applied OUTSIDE the
/// `.background(...)` fill chain so the fill commits to its own opaque
/// layer first; the shadow then applies to the composed card on the
/// outside (vs. composing fill + shadow into a single offscreen layer,
/// which would leave the corners visibly translucent against any
/// backdrop).
///
/// **T-747 / CL-144 (DUT-41) — sibling Material dim overlay removed.**
/// The earlier T-744 note here described the popup's neighbour in the
/// ``RecipeDetailRatingsSection/gatedRateAndReviewCard`` ZStack as a
/// `Rectangle().fill(.ultraThinMaterial)` that dimmed the blurred
/// composer behind the popup. T-747 deleted that view entirely — the
/// composer's `.blur(radius: 10)` alone communicates "this is gated"
/// without the additional dim layer reading as a grey frame around the
/// popup. The popup card's own background composition is unchanged.
///
/// Accessibility: the CTA carries ``accessibilityIdentifier`` so a
/// future L5 E2E journey ("set up a profile from the recipe gate") can
/// drive the flow without revisiting the view code. The card itself
/// reads as a contained accessibility group so VoiceOver announces it
/// as one coherent "Set up your profile…" element rather than three
/// separate Text rows.
///
/// Spec trace: US-44 AC-44.10 (amended T-744 / CL-141, again T-747 / CL-144); CL-138; DUT-36 Phase c.
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

            Text("Set Up Your Profile")
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
                        // CL-304 / DUT-537 — button tier: tappable CTA → Capsule pill.
                        Capsule(style: .continuous)
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
            RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
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
