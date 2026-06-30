import DODDesignSystem
import DODSupport
import SwiftUI

// The page compositions for ``HeatCoachView`` (DUT-48; CL-274 redesign), split
// out of `HeatCoachView.swift` so each file stays under the `file_length` cap
// and the struct body stays under `type_body_length`.
//
//   - Coals page: ``setupCard`` → ``resultCard`` → ``conditionsCard``.
//   - Feel page:  ``feelReferenceSection`` (the cook-by-feel cues — the point).
//   - Tips page:  ``coalManagementSection`` (coal habits + wind guidance).
//
// The cue / habit / wind copy is one source of truth in ``DutchOvenHeatCoach``
// (DODSupport) and is pinned by `DutchOvenHeatCoachTests`.

extension HeatCoachView {

    // MARK: - Coals page: setup

    var setupCard: some View {
        VStack(alignment: .leading, spacing: DODSpacing.md) {
            sectionHeader("Start Here")

            labeledRow("Oven size") {
                Picker("Oven size", selection: $ovenDiameterInches) {
                    ForEach(HeatCoachModel.ovenSizes, id: \.self) { size in
                        Text("\(size)\"").tag(size)
                    }
                }
                .pickerStyle(.menu)
                .tint(DODColor.accent)
                .accessibilityIdentifier("heat-coach-oven-size")
            }

            labeledRow("Cooking style") {
                accentSelector(
                    selection: $style,
                    options: [(.even, "Even"), (.baking, "Baking")],
                    accessibilityID: "heat-coach-style"
                )
            }
        }
        .padding(DODSpacing.md)
        .cardSurface()
        .accessibilityIdentifier("heat-coach-setup")
    }

    // MARK: - Coals page: the starting estimate

    var resultCard: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Text("A starting point. Then cook by feel.")
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelOnAccent.opacity(0.9))
                .textCase(.uppercase)

            Text(coachModel.coalHeadline)
                .dodFont(DODType.displayMedium)
                .foregroundStyle(DODColor.labelOnAccent)
                .fixedSize(horizontal: false, vertical: true)

            Text(coachModel.styleNote)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelOnAccent.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DODSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                .fill(DODColor.accent)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("heat-coach-result")
    }

    // MARK: - Coals page: optional condition fine-tuning + adjustment notes

    @ViewBuilder
    func conditionsCard(_ coachModel: HeatCoachModel) -> some View {
        VStack(alignment: .leading, spacing: DODSpacing.md) {
            sectionHeader("Fine-Tune for Conditions")

            Text("Optional. The estimate already works for a calm, mild day.")
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)

            labeledRow("Elevation") {
                Stepper(value: $elevationFeet, in: 0...15000, step: 500) {
                    Text(elevationFeet == 0 ? "Sea level" : "\(elevationFeet) ft")
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.label)
                }
                .accessibilityIdentifier("heat-coach-elevation")
            }

            labeledRow("Air temperature") {
                accentSelector(
                    selection: $ambient,
                    options: [(.hot, "Hot"), (.mild, "Mild"), (.cold, "Cold")],
                    accessibilityID: "heat-coach-ambient"
                )
            }

            Toggle(isOn: $windy) {
                Text("Windy day")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.label)
            }
            .tint(DODColor.accent)
            .accessibilityIdentifier("heat-coach-wind")

            let notes = adjustmentNotes(coachModel)
            if !notes.isEmpty {
                Divider().overlay(DODColor.surfaceDivider)
                VStack(alignment: .leading, spacing: DODSpacing.xs) {
                    Text("What changes")
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.labelSecondary)
                    ForEach(notes, id: \.self) { note in
                        adjustmentLine(note)
                    }
                }
            }
        }
        .padding(DODSpacing.md)
        .cardSurface()
        .accessibilityIdentifier("heat-coach-conditions")
    }

    /// The adjustment notes that apply to the current conditions, in order. A
    /// mild / sea-level / calm setup yields only the always-on replenish note.
    private func adjustmentNotes(_ coachModel: HeatCoachModel) -> [String] {
        var notes: [String] = []
        if let ambientNote = coachModel.ambientNote { notes.append(ambientNote) }
        if let elevationNote = coachModel.elevationNote { notes.append(elevationNote) }
        notes.append(coachModel.replenishNote)
        if let windCoalNote = coachModel.windCoalNote { notes.append(windCoalNote) }
        if let windNote = coachModel.windNote { notes.append(windNote) }
        return notes
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

    // MARK: - Feel page: cook-by-feel cues (the heart of the feature)

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
            RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
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

    // MARK: - Tips page: coal-management habits + wind guidance

    var coalManagementSection: some View {
        VStack(alignment: .leading, spacing: DODSpacing.sm) {
            sectionHeader("Coal Management")

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
