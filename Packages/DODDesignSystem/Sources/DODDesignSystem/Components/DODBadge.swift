import SwiftUI

/// US-43 Phase c (T-712) — brand badges. Namespace-only enum (like
/// ``DODColor`` / ``DODType``) so call sites read `DODBadge.Numbered(...)`.
public enum DODBadge {

    /// The numbered "Popular" rank medallion: a white ``DODColor/labelOnAccent``
    /// number on a burnt-orange ``DODColor/accent`` fill. A small-pill accent
    /// fill is allowed by the design conventions (never a full content-card
    /// fill), matching ``OwnerBadge``'s treatment. AC-43.5 named this the first
    /// consumer of `LabelOnAccent`.
    ///
    /// The rank (1, 2, 3…) is supplied by the caller. The *popularity signal*
    /// itself is a caller concern — the Feed's first-cut wiring treats the first
    /// N cards as "Popular" pending a real signal (see US-43 Phase c notes).
    public struct Numbered: View {

        private let number: Int

        public init(number: Int) {
            self.number = number
        }

        public var body: some View {
            Text("\(number)")
                .dodFont(DODType.caption)
                .fontWeight(.bold)
                .foregroundStyle(DODColor.labelOnAccent)
                .monospacedDigit()
                // Fixed diameter so 1- and 2-digit ranks read as the same medallion.
                .frame(width: 26, height: 26)
                .background(Circle().fill(DODColor.accent))
                // A subtle surface-colored ring so the medallion lifts off a busy
                // hero photo without a new color token.
                .overlay(Circle().stroke(DODColor.surfaceElevated, lineWidth: 1.5))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Popular, number \(number)")
        }
    }
}

#Preview("Numbered badges") {
    HStack(spacing: DODSpacing.sm) {
        DODBadge.Numbered(number: 1)
        DODBadge.Numbered(number: 2)
        DODBadge.Numbered(number: 3)
        DODBadge.Numbered(number: 12)
    }
    .padding(DODSpacing.md)
    .background(DODColor.surface)
}
