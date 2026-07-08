import DODDesignSystem
import DODSupport
import SwiftUI

// The cook-by-feel reference for ``HeatCoachView`` (v2 de-listed redesign),
// split out of `HeatCoachView+Sections` so each file stays under the
// `file_length` cap.
//
// v2 rethink: the six cues used to sit always-open as an 18-line wall of
// identical checkmark / arrow rows, and the coal-management tips repeated a
// flame bullet on every line. Now each cue is a tap-to-expand card fronted by a
// distinct sensory icon (so the column reads as six calm rows, not a wall), and
// the tips group drops the per-line bullets for two clean, spaced blocks.
//
// The cue / habit / wind copy is one source of truth in ``DutchOvenHeatCoach``
// (DODSupport) and is pinned by `DutchOvenHeatCoachTests` — the view only
// arranges it.

extension HeatCoachView {

    // MARK: - Cook-by-feel cues (progressive-disclosure sensory cards)

    var feelReferenceSection: some View {
        VStack(alignment: .leading, spacing: DODSpacing.sm) {
            sectionHeader("Cook by Feel")

            Text(
                "The estimate just gets your coals going. From there, your eyes, ears, and nose run the cook. "
                    + "That's the Dutch Oven Daddy way."
            )
            .dodFont(DODType.body)
            .foregroundStyle(DODColor.labelSecondary)
            .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: DODSpacing.xs) {
                ForEach(DutchOvenHeatCoach.feelCues) { cue in
                    feelCueCard(cue)
                }
            }
        }
        .accessibilityIdentifier("heat-coach-feel")
    }

    /// One cook-by-feel cue as a tap-to-expand card: an accent sensory icon +
    /// title collapsed; the "on track" read and the fix revealed on tap.
    private func feelCueCard(_ cue: FeelCue) -> some View {
        let isOpen = expandedFeelCue == cue.title
        return VStack(alignment: .leading, spacing: DODSpacing.sm) {
            Button {
                expandedFeelCue = isOpen ? nil : cue.title
            } label: {
                HStack(spacing: DODSpacing.sm) {
                    Text(cue.title)
                        .dodFont(DODType.bodyEmphasized)
                        .foregroundStyle(DODColor.label)
                    Spacer(minLength: DODSpacing.sm)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DODColor.labelSecondary)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(isOpen ? "Collapse" : "Expand")

            if isOpen {
                VStack(alignment: .leading, spacing: DODSpacing.md) {
                    feelGuidanceRow(label: "On Track", tint: DODColor.accent, text: cue.onTrack)
                    feelGuidanceRow(label: "Adjust", tint: DODColor.labelSecondary, text: cue.adjust)
                }
                .padding(.top, DODSpacing.xxs)
            }
        }
        .padding(DODSpacing.md)
        .cardSurface()
    }

    /// One line inside an expanded cue: a small uppercase intent LABEL ("On
    /// Track" in accent, "Adjust" in secondary) over the copy — labels instead
    /// of icons, so the expanded card stays calm and reads at a glance.
    private func feelGuidanceRow(label: String, tint: Color, text: String) -> some View {
        VStack(alignment: .leading, spacing: DODSpacing.xxs) {
            Text(label)
                .dodFont(DODType.caption)
                .foregroundStyle(tint)
                .textCase(.uppercase)
            Text(text)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Coal-management habits + wind guidance (collapsed, de-listed)

    @ViewBuilder
    var tipsGroup: some View {
        DisclosureGroup(isExpanded: $showTips) {
            tipsContent
                .padding(.top, DODSpacing.md)
        } label: {
            Text("Coal Management & Wind")
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.label)
                .frame(minHeight: 44, alignment: .leading)  // DUT-291: 44pt tap target
        }
        .tint(DODColor.accent)
        .padding(DODSpacing.md)
        .cardSurface()
        .accessibilityIdentifier("heat-coach-coal-management")
    }

    @ViewBuilder
    private var tipsContent: some View {
        VStack(alignment: .leading, spacing: DODSpacing.lg) {
            tipsBlock(
                icon: "flame.fill",
                title: "Steady Heat",
                items: DutchOvenHeatCoach.coalManagementHabits
            )
            tipsBlock(
                icon: "wind",
                title: "Wind",
                items: DutchOvenHeatCoach.windGuidance
            )
        }
    }

    /// A tips block: one accent icon + title heading, then the guidance as clean
    /// well-spaced lines (no per-line bullet — that repetition was the clutter).
    private func tipsBlock(icon: String, title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: DODSpacing.sm) {
            HStack(spacing: DODSpacing.xs) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(DODColor.accent)
                    .accessibilityHidden(true)
                Text(title)
                    .dodFont(DODType.bodyEmphasized)
                    .foregroundStyle(DODColor.label)
            }
            ForEach(items, id: \.self) { item in
                Text(item)
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.labelSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
