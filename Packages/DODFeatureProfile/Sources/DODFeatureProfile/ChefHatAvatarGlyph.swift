import DODDesignSystem
import SwiftUI

/// Profile-avatar placeholder for the guest / unnamed state: a chef-hat person
/// silhouette in white (`DODColor.labelOnAccent`) on the caller's orange
/// circle, shown instead of a bare "?" so the empty avatar carries the app's
/// personality (a cast-iron cook, not a question mark). T-787 / CL-183 (DUT-93).
///
/// Geometry is Spencer's hand-drawn "Chef Profile" design, translated from its
/// source 4267x4267 SVG into themeable SwiftUI shapes — head + body + three
/// toque puffs + a band — so it stays crisp at any diameter and tints with the
/// design system (no bitmap to ship or scale). All parts are the same white, so
/// they union into one silhouette. The body circle is large and runs off the
/// bottom; the `Circle` clip trims it into the head-and-shoulders cut. The whole
/// figure is scaled to ~94% so the toque clears the avatar's circular edge.
/// Decorative — the parent `InitialLetterAvatarView` owns the accessibility
/// treatment.
///
/// Every dimension is a fraction of `diameter` so the glyph scales with the
/// avatar (40pt rows, 60pt Settings, 120pt edit header).
public struct ChefHatAvatarGlyph: View {

    public let diameter: CGFloat

    public init(diameter: CGFloat = 60) {
        self.diameter = diameter
    }

    public var body: some View {
        // 0.94 inset so the toque clears the circular avatar edge; fractions
        // are normalized from the source SVG's 4267x4267 viewBox.
        let scaled = 0.94 * diameter
        ZStack {
            // Body / shoulders — a large circle whose top arc reads as the
            // bust; the Circle clip below trims it to the avatar's edge.
            Circle()
                .frame(width: 0.8720 * scaled, height: 0.8720 * scaled)
                .offset(y: 0.5702 * scaled)

            // Head.
            Circle()
                .frame(width: 0.3574 * scaled, height: 0.3574 * scaled)
                .offset(y: -0.0279 * scaled)

            // Toque band (the cuff that sits on the head), covered on its sides
            // and top by the puffs below — so its square corners never show.
            Rectangle()
                .frame(width: 0.2540 * scaled, height: 0.1102 * scaled)
                .offset(y: -0.2066 * scaled)

            // Toque poof — three overlapping circles billowing above the band.
            Circle()
                .frame(width: 0.2684 * scaled, height: 0.2684 * scaled)
                .offset(x: -0.1853 * scaled, y: -0.2980 * scaled)
            Circle()
                .frame(width: 0.2684 * scaled, height: 0.2684 * scaled)
                .offset(x: 0.1848 * scaled, y: -0.2980 * scaled)
            Circle()
                .frame(width: 0.2590 * scaled, height: 0.2590 * scaled)
                .offset(x: 0.0031 * scaled, y: -0.3637 * scaled)
        }
        .frame(width: diameter, height: diameter)
        .foregroundStyle(DODColor.labelOnAccent)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

#Preview("ChefHatAvatarGlyph — on accent") {
    ChefHatAvatarGlyph(diameter: 120)
        .background(Circle().fill(DODColor.accent).frame(width: 120, height: 120))
        .padding()
        .background(DODColor.surface)
}
