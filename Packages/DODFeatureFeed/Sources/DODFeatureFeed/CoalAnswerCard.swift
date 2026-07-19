import DODDesignSystem
import DODSupport
import SwiftUI

/// The **starting-coals answer card** — the "here's your coal count" beat of the
/// Dutch Oven Heat Coach, extracted (DUT) into a standalone, data-driven view so
/// it can be reused *outside* the full coach: the First Cookout fire step embeds
/// it inline so a beginner sees the real coal count + lid/bottom split without
/// leaving the flow.
///
/// It's the former `HeatCoachView.answerCard` + `coalSplitDiagram(_:)` lifted out
/// of the view's `@State` internals. It takes everything it renders via `init`:
///   - `split` — the ``CoalSplit`` to draw (the coach passes its
///     condition-adjusted split; the fire step passes the plain starting split).
///   - `conditionsAdjusted` — when true, the "Already adjusted for your
///     conditions." note shows (the coach sets this when a hot/cold/windy day has
///     already moved the count; the fire step leaves it false).
///   - `cookTimeLine` — the optional elevation cook-time readout under a divider
///     (the coach always passes one; the fire step passes `nil`, so the divider +
///     line are omitted).
///   - `recipeContextLine` — the optional "For this recipe at N°F." line.
///
/// Accessibility: the dots are DECORATIVE (`.accessibilityHidden`) — VoiceOver
/// must not read 24 individual dots. The whole diagram is ONE accessibility
/// element with a combined summary label (``coalDiagramAccessibilityLabel``),
/// e.g. "Starting coals: about 24 — 18 on the lid, 6 underneath." The copy here
/// is pinned by `HeatCoachViewTests`, so it must not drift.
struct CoalAnswerCard: View {

    /// The coal split to draw + summarize.
    let split: CoalSplit
    /// Show the "Already adjusted for your conditions." note (the coach's
    /// condition-shifted count; false for the plain fire-step estimate).
    let conditionsAdjusted: Bool
    /// The optional elevation cook-time readout, shown under a divider. `nil`
    /// omits both the divider and the line (the fire step has no elevation input).
    let cookTimeLine: String?
    /// The optional "For this recipe at N°F." context line.
    let recipeContextLine: String?

    init(
        split: CoalSplit,
        conditionsAdjusted: Bool = false,
        cookTimeLine: String? = nil,
        recipeContextLine: String? = nil
    ) {
        self.split = split
        self.conditionsAdjusted = conditionsAdjusted
        self.cookTimeLine = cookTimeLine
        self.recipeContextLine = recipeContextLine
    }

    var body: some View {
        VStack(spacing: DODSpacing.sm) {
            Text("A Starting Point. Then Cook by Feel.")
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
                .textCase(.uppercase)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // DUT-600 — the diagram reflects the CONDITION-adjusted count so a
            // hot/cold/windy day moves the starting point, not just the notes.
            coalSplitDiagram(split)

            // DUT-653 — when conditions have already shifted the count, say so
            // right on the diagram. Otherwise the cook double-counts the "What
            // Changes" ranges (which describe THIS adjustment) on top of a total
            // that already bakes them in. Hidden at mild + calm (delta 0...0),
            // where the diagram equals the plain starting point.
            if conditionsAdjusted {
                Text("Already adjusted for your conditions.")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("heat-coach-adjusted-note")
            }

            // DUT-601 — elevation adjusts cook TIME (not coals, per the DOD
            // method), so surface it live in the answer so the Elevation input
            // also visibly moves the recommendation. `nil` (the fire step) omits it.
            if let cookTimeLine {
                Divider().overlay(DODColor.surfaceDivider)
                Text(cookTimeLine)
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("heat-coach-cook-time")
            }

            if let recipeContextLine {
                Text(recipeContextLine)
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("heat-coach-recipe-context")
            }
        }
        .padding(DODSpacing.lg)
        .frame(maxWidth: .infinity)
        .cardSurface()
        .accessibilityIdentifier("heat-coach-result")
    }

    // MARK: - Coal-split diagram

    /// The visual coal-split diagram — lid dots over the oven body over bottom
    /// dots. `split` is the current ``CoalSplit`` the card was handed.
    private func coalSplitDiagram(_ split: CoalSplit) -> some View {
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
        // A wrapping flow, not an HStack: dots pack left-to-right and wrap to the
        // next centered row when they'd exceed the card width. A plain HStack
        // overflowed and stretched the whole answer card for baking splits, whose
        // lid is 3/4 of the total — 18 dots at 12", 24 at 16" (DUT bugfix). Even
        // splits (lid = half) never got wide enough to trip it.
        CoalDotFlowLayout(spacing: DODSpacing.xs) {
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
    /// "Starting coals: about 24, 18 on the lid and 6 underneath." Static + pure
    /// so a unit test can pin it without a snapshot host.
    static func coalDiagramAccessibilityLabel(_ split: CoalSplit) -> String {
        "Starting coals: about \(split.total), \(split.lid) on the lid and \(split.bottom) underneath."
    }
}

/// A minimal flow layout for the coal dots: identical fixed-size items packed
/// left-to-right, wrapping to a new centered row when they'd exceed the proposed
/// width. Keeps a large baking lid split (up to 24 dots) from overflowing and
/// stretching the answer card. iOS 16+ `Layout`.
private struct CoalDotFlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let item = subviews.first?.sizeThatFits(.unspecified) else { return .zero }
        let maxWidth = proposal.width ?? .infinity
        let perRow = maxPerRow(maxWidth: maxWidth, itemWidth: item.width)
        let rows = Int(ceil(Double(subviews.count) / Double(perRow)))
        let width =
            maxWidth.isFinite
            ? maxWidth
            : CGFloat(subviews.count) * item.width + CGFloat(max(0, subviews.count - 1)) * spacing
        let height = CGFloat(rows) * item.height + CGFloat(max(0, rows - 1)) * spacing
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let item = subviews.first?.sizeThatFits(.unspecified) else { return }
        let perRow = maxPerRow(maxWidth: bounds.width, itemWidth: item.width)
        var index = 0
        var y = bounds.minY
        while index < subviews.count {
            let rowCount = min(perRow, subviews.count - index)
            let rowWidth = CGFloat(rowCount) * item.width + CGFloat(rowCount - 1) * spacing
            var x = bounds.minX + (bounds.width - rowWidth) / 2
            for _ in 0..<rowCount {
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item)
                )
                x += item.width + spacing
                index += 1
            }
            y += item.height + spacing
        }
    }

    /// How many identical items fit across `maxWidth` with `spacing` between.
    private func maxPerRow(maxWidth: CGFloat, itemWidth: CGFloat) -> Int {
        guard maxWidth.isFinite, itemWidth > 0 else { return subviewCountUpperBound }
        return max(1, Int((maxWidth + spacing) / (itemWidth + spacing)))
    }

    /// A safe "all on one row" fallback for an unbounded proposal.
    private var subviewCountUpperBound: Int { .max }
}
