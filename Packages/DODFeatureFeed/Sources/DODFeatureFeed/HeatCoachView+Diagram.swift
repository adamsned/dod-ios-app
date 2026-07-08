import DODDesignSystem
import DODSupport
import SwiftUI

// The visual coal-split diagram for ``HeatCoachView`` (DUT-584 answer-first
// redesign), split out of `HeatCoachView.swift` so each file stays under the
// `file_length` cap.
//
// The diagram makes the coal count instantly readable: a row of dots for the
// lid coals, the oven body showing the big total + "N on the lid · M
// underneath", and a row of dots underneath. The dot counts reflect the real
// ``CoalSplit`` (lid/bottom).
//
// Accessibility: the dots are DECORATIVE (`.accessibilityHidden`) — VoiceOver
// must not read 24 individual dots. The whole diagram is ONE accessibility
// element with a combined summary label (``coalDiagramAccessibilityLabel``),
// e.g. "Starting coals: about 24 — 18 on the lid, 6 underneath."

extension HeatCoachView {

    /// The visual coal-split diagram — lid dots over the oven body over bottom
    /// dots. Rendered inside the answer card. `split` is the current
    /// ``CoalSplit`` (from ``HeatCoachModel/coalSplit``).
    func coalSplitDiagram(_ split: CoalSplit) -> some View {
        VStack(spacing: DODSpacing.sm) {
            coalDotRow(count: split.lid)
            ovenBody(split)
            coalDotRow(count: split.bottom)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.coalDiagramAccessibilityLabel(split))
        .accessibilityIdentifier("heat-coach-diagram")
    }

    /// One row of decorative coal dots — one coal per dot. Hidden from
    /// VoiceOver — the count is spoken once by the diagram's combined label,
    /// never as N separate dots.
    private func coalDotRow(count: Int) -> some View {
        HStack(spacing: DODSpacing.xs) {
            ForEach(0..<max(0, count), id: \.self) { _ in
                coalDot
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    /// A single coal: a flat warm-orange fill with a thin cast-iron rim for
    /// definition. v2 dropped the earlier radial-gradient specular highlight so
    /// the dots read as coals calmly, without the glossy sheen.
    private var coalDot: some View {
        Circle()
            .fill(DODColor.accent)
            .frame(width: 12, height: 12)
            .overlay(
                Circle().strokeBorder(DODColor.castIronBrown.opacity(0.35), lineWidth: 0.5)
            )
    }

    /// The oven body: a small "Starting Coals" caption, the big total, then the
    /// "N on the lid · M underneath" split line. The caption self-labels the
    /// number now that the hero card dropped its separate heading. Decorative
    /// here too — the diagram's combined label speaks the whole thing.
    private func ovenBody(_ split: CoalSplit) -> some View {
        VStack(spacing: DODSpacing.xxs) {
            Text("Starting Coals")
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
                .textCase(.uppercase)
            // The big total is where burnt orange earns its one bold moment on
            // the calm card — the number, not the whole surface.
            Text("~\(split.total)")
                .dodFont(DODType.displayLarge)
                .foregroundStyle(DODColor.accent)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(split.lid) on the lid · \(split.bottom) underneath")
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, DODSpacing.md)
        .frame(maxWidth: .infinity)
        // A recessed well between the two ember rows — `surface` inside the
        // elevated card with a hairline, the same idiom as the segmented-control
        // track. Reads as the oven the coals sit on, in both light + dark.
        .background(
            RoundedRectangle(cornerRadius: DODRadius.inner, style: .continuous)
                .fill(DODColor.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DODRadius.inner, style: .continuous)
                .strokeBorder(DODColor.surfaceDivider, lineWidth: 1)
        )
        .accessibilityHidden(true)
    }

    /// The single combined VoiceOver label for the whole diagram, e.g.
    /// "Starting coals: about 24 — 18 on the lid, 6 underneath." Static + pure
    /// so a unit test can pin it without a snapshot host.
    static func coalDiagramAccessibilityLabel(_ split: CoalSplit) -> String {
        "Starting coals: about \(split.total) — \(split.lid) on the lid, \(split.bottom) underneath."
    }
}
