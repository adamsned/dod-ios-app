import DODDesignSystem
import DODSupport
import SwiftUI

// The adjustment-notes, cook-by-feel reference, and coal-management sections
// of ``HeatCoachView`` (DUT-48). Split out of `HeatCoachView.swift` so that
// file stays under the 400-line `file_length` cap.
//
// Visual priority (DUT-48): the cook-by-feel reference is the point of the
// feature, so it is the most prominent section — full-width cue rows with a
// clear "on track / adjust" pairing — not a footnote under the number.

extension HeatCoachView {

    // MARK: - Adjustment notes (the conditions change the starting point)

    @ViewBuilder
    func adjustmentsCard(_ coachModel: HeatCoachModel) -> some View {
        VStack(alignment: .leading, spacing: DODSpacing.sm) {
            sectionHeader("Adjust for your conditions")

            Text(
                "These tweak your starting number. Watch the oven, not the clock. "
                    + "The cues below tell you what's really happening."
            )
            .dodFont(DODType.body)
            .foregroundStyle(DODColor.labelSecondary)
            .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: DODSpacing.xs) {
                if let ambientNote = coachModel.ambientNote {
                    adjustmentLine(ambientNote)
                }
                if let elevationNote = coachModel.elevationNote {
                    adjustmentLine(elevationNote)
                }
                adjustmentLine(coachModel.replenishNote)
                if let windNote = coachModel.windNote {
                    adjustmentLine(windNote)
                }
            }
        }
        .padding(DODSpacing.md)
        .cardSurface()
        .accessibilityIdentifier("heat-coach-adjustments")
    }

    private func adjustmentLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: DODSpacing.xs) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundStyle(DODColor.accent)
                .padding(.top, DODSpacing.xs)
                .accessibilityHidden(true)
            Text(text)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Cook-by-feel reference (the heart of the feature)

    @ViewBuilder
    var feelReferenceSection: some View {
        VStack(alignment: .leading, spacing: DODSpacing.sm) {
            sectionHeader("Cook by feel")

            Text(
                "The estimate just gets your coals going. From there, your eyes, ears, and nose run the cook. "
                    + "That's the Dutch Oven Daddy way."
            )
            .dodFont(DODType.body)
            .foregroundStyle(DODColor.labelSecondary)
            .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: DODSpacing.sm) {
                ForEach(DutchOvenHeatCoach.feelCues) { cue in
                    feelCueCard(cue)
                }
            }
        }
        .accessibilityIdentifier("heat-coach-feel")
    }

    private func feelCueCard(_ cue: FeelCue) -> some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Text(cue.title)
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.label)

            signalRow(symbol: "checkmark.circle.fill", tint: DODColor.accent, text: cue.onTrack)
            signalRow(symbol: "arrow.triangle.2.circlepath", tint: DODColor.labelSecondary, text: cue.adjust)
        }
        .padding(DODSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DODSpacing.sm, style: .continuous)
                .fill(DODColor.surfaceElevated)
        )
    }

    private func signalRow(symbol: String, tint: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: DODSpacing.xs) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .padding(.top, 2)
                .accessibilityHidden(true)
            Text(text)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Coal management habits

    @ViewBuilder
    var coalManagementSection: some View {
        VStack(alignment: .leading, spacing: DODSpacing.sm) {
            sectionHeader("Coal management")

            VStack(alignment: .leading, spacing: DODSpacing.sm) {
                ForEach(DutchOvenHeatCoach.coalManagementHabits, id: \.self) { habit in
                    habitLine(habit)
                }
            }
            .padding(DODSpacing.md)
            .cardSurface()

            Text("Wind")
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.label)
                .padding(.top, DODSpacing.xs)

            VStack(alignment: .leading, spacing: DODSpacing.sm) {
                ForEach(DutchOvenHeatCoach.windGuidance, id: \.self) { tip in
                    habitLine(tip)
                }
            }
            .padding(DODSpacing.md)
            .cardSurface()
        }
        .accessibilityIdentifier("heat-coach-coal-management")
    }

    private func habitLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: DODSpacing.xs) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12))
                .foregroundStyle(DODColor.accent)
                .padding(.top, 2)
                .accessibilityHidden(true)
            Text(text)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
