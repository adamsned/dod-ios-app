import DODDesignSystem
import DODSupport
import SwiftUI

// The section compositions for ``HeatCoachView`` (DUT-48; DUT-584 answer-first
// redesign), split out of `HeatCoachView.swift` so each file stays under the
// `file_length` cap and the struct body stays under `type_body_length`.
//
//   - ``answerCard`` — the answer first: the coal-split diagram (in `+Diagram`)
//     under the "starting point, then cook by feel" framing + optional recipe
//     context line.
//   - ``primaryInputsCard`` — the two minimal inputs (Oven Size + Cooking Style).
//   - ``conditionsGroup`` — the optional collapsed "Adjust for Conditions"
//     expander (elevation / air temp / wind + the adjustment notes).
//   - ``feelReferenceSection`` — the cook-by-feel cues, always visible (the point).
//   - ``tipsGroup`` — coal-management habits + wind guidance, collapsed.
//
// The cue / habit / wind copy is one source of truth in ``DutchOvenHeatCoach``
// (DODSupport) and is pinned by `DutchOvenHeatCoachTests`.

extension HeatCoachView {

    // MARK: - The answer, first + visual

    var answerCard: some View {
        VStack(alignment: .leading, spacing: DODSpacing.md) {
            Text("A starting point. Then cook by feel.")
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelOnAccent.opacity(0.9))
                .textCase(.uppercase)
                .fixedSize(horizontal: false, vertical: true)

            Text("Your Starting Coals")
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.labelOnAccent)
                .fixedSize(horizontal: false, vertical: true)

            coalSplitDiagram(coachModel.coalSplit)

            if let context = recipeContextLine {
                Text(context)
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelOnAccent.opacity(0.95))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("heat-coach-recipe-context")
            }

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
        .accessibilityIdentifier("heat-coach-result")
    }

    /// The recipe context line ("For this recipe at 350°F"), shown only when the
    /// coach was seeded from a recipe with a target temperature. Split out so the
    /// `if let` in ``answerCard`` stays a single line (swift-format vs SwiftLint
    /// `opening_brace` peace).
    private var recipeContextLine: String? {
        guard let seedTemperatureF else { return nil }
        return "For this recipe at \(seedTemperatureF)°F."
    }

    // MARK: - Minimal primary inputs (live-update the answer)

    var primaryInputsCard: some View {
        VStack(alignment: .leading, spacing: DODSpacing.md) {
            labeledRow("Oven Size") {
                Picker("Oven Size", selection: $ovenDiameterInches) {
                    ForEach(HeatCoachModel.ovenSizes, id: \.self) { size in
                        Text("\(size)\"").tag(size)
                    }
                }
                .pickerStyle(.menu)
                .tint(DODColor.accent)
                .accessibilityIdentifier("heat-coach-oven-size")
            }

            labeledRow("Cooking Style") {
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

    // MARK: - Optional condition fine-tuning + adjustment notes (collapsed)

    @ViewBuilder
    func conditionsGroup(_ coachModel: HeatCoachModel) -> some View {
        DisclosureGroup(isExpanded: $showConditions) {
            conditionsContent(coachModel)
                .padding(.top, DODSpacing.sm)
        } label: {
            VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                Text("Adjust for Conditions")
                    .dodFont(DODType.heading)
                    .foregroundStyle(DODColor.label)
                Text("Optional. The estimate already works for a calm, mild day.")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minHeight: 44, alignment: .leading)  // DUT-291: 44pt tap target
        }
        .tint(DODColor.accent)
        .padding(DODSpacing.md)
        .cardSurface()
        .accessibilityIdentifier("heat-coach-conditions")
    }

    @ViewBuilder
    private func conditionsContent(_ coachModel: HeatCoachModel) -> some View {
        VStack(alignment: .leading, spacing: DODSpacing.md) {
            labeledRow("Elevation") {
                Stepper(value: $elevationFeet, in: 0...15000, step: 500) {
                    Text(elevationFeet == 0 ? "Sea level" : "\(elevationFeet) ft")
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.label)
                }
                .accessibilityIdentifier("heat-coach-elevation")
            }

            labeledRow("Air Temperature") {
                accentSelector(
                    selection: $ambient,
                    options: [(.hot, "Hot"), (.mild, "Mild"), (.cold, "Cold")],
                    accessibilityID: "heat-coach-ambient"
                )
            }

            Toggle(isOn: $windy) {
                Text("Windy Day")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.label)
            }
            .tint(DODColor.accent)
            .accessibilityIdentifier("heat-coach-wind")

            let notes = adjustmentNotes(coachModel)
            if !notes.isEmpty {
                Divider().overlay(DODColor.surfaceDivider)
                VStack(alignment: .leading, spacing: DODSpacing.xs) {
                    Text("What Changes")
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.labelSecondary)
                    ForEach(notes, id: \.self) { note in
                        adjustmentLine(note)
                    }
                }
            }
        }
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

    // MARK: - Cook-by-feel cues (the heart of the feature — always visible)

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

    // MARK: - Coal-management habits + wind guidance (collapsed)

    @ViewBuilder
    var tipsGroup: some View {
        DisclosureGroup(isExpanded: $showTips) {
            tipsContent
                .padding(.top, DODSpacing.sm)
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
        VStack(alignment: .leading, spacing: DODSpacing.md) {
            VStack(alignment: .leading, spacing: DODSpacing.sm) {
                ForEach(DutchOvenHeatCoach.coalManagementHabits, id: \.self) { habit in
                    habitLine(habit)
                }
            }

            Text("Wind")
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.label)

            VStack(alignment: .leading, spacing: DODSpacing.sm) {
                ForEach(DutchOvenHeatCoach.windGuidance, id: \.self) { tip in
                    habitLine(tip)
                }
            }
        }
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
