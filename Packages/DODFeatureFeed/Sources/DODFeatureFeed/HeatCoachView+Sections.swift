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
        VStack(spacing: DODSpacing.sm) {
            Text("A Starting Point. Then Cook by Feel.")
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelOnAccent.opacity(0.9))
                .textCase(.uppercase)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // DUT-600 — the diagram reflects the CONDITION-adjusted count so a
            // hot/cold/windy day moves the starting point, not just the notes.
            coalSplitDiagram(coachModel.adjustedCoalSplit)

            // DUT-653 — when conditions have already shifted the count, say so
            // right on the diagram. Otherwise the cook double-counts the "What
            // Changes" ranges (which describe THIS adjustment) on top of a total
            // that already bakes them in. Hidden at mild + calm (delta 0...0),
            // where the diagram equals the plain starting point.
            if coachModel.conditionCoalDelta != 0...0 {
                Text("Already adjusted for your conditions.")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelOnAccent.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("heat-coach-adjusted-note")
            }

            // DUT-601 — elevation adjusts cook TIME (not coals, per the DOD
            // method), so surface it live in the answer so the Elevation input
            // also visibly moves the recommendation. Divider reads on accent.
            Divider().overlay(DODColor.labelOnAccent.opacity(0.25))
            Text(coachModel.elevationCookTimeLine)
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelOnAccent.opacity(0.95))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("heat-coach-cook-time")

            if let context = recipeContextLine {
                Text(context)
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelOnAccent.opacity(0.95))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("heat-coach-recipe-context")
            }
        }
        .padding(DODSpacing.lg)
        .frame(maxWidth: .infinity)
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
            // Oven Size as a compact stepper row: the current size reads large on
            // the left, the − / + control sits inline on the right. Tighter and
            // more tactile than a dropdown, and it never covers the answer.
            labeledRow("Oven Size") {
                Stepper(
                    value: $ovenDiameterInches,
                    in: sizeRange,
                    step: 2
                ) {
                    Text("\(ovenDiameterInches)\" Diameter")
                        .dodFont(DODType.bodyEmphasized)
                        .foregroundStyle(DODColor.label)
                }
                .tint(DODColor.accent)
                .accessibilityIdentifier("heat-coach-oven-size")
            }

            Divider().overlay(DODColor.surfaceDivider)

            labeledRow("Cooking Style") {
                accentSelector(
                    selection: $style,
                    options: [(.even, "Even"), (.baking, "Baking")],
                    accessibilityID: "heat-coach-style"
                )
            }

            // The style note explains the split at the point of choice — moved
            // out of the hero so the result stays a clean number.
            Text(coachModel.styleNote)
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("heat-coach-style-note")
        }
        .padding(DODSpacing.md)
        .cardSurface()
        .accessibilityIdentifier("heat-coach-setup")
    }

    /// The oven-diameter stepper bounds, derived from the model's supported
    /// sizes (8-16") so the stepper and the old menu offer the same range.
    private var sizeRange: ClosedRange<Int> {
        let sizes = HeatCoachModel.ovenSizes
        return (sizes.min() ?? 8)...(sizes.max() ?? 16)
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

            // DUT-598 — the six cues were six floating cards (a wall). They now
            // live as compact rows inside ONE card, hairline-divided, so the
            // section reads as a single reference the eye can scan.
            VStack(spacing: 0) {
                ForEach(Array(DutchOvenHeatCoach.feelCues.enumerated()), id: \.element.id) { index, cue in
                    if index > 0 {
                        Divider().overlay(DODColor.surfaceDivider)
                    }
                    feelCueRow(cue)
                }
            }
            .padding(.vertical, DODSpacing.xxs)
            .cardSurface()
        }
        .accessibilityIdentifier("heat-coach-feel")
    }

    private func feelCueRow(_ cue: FeelCue) -> some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Text(cue.title)
                .dodFont(DODType.bodyEmphasized)
                .foregroundStyle(DODColor.label)

            signalRow(symbol: "checkmark.circle.fill", tint: DODColor.accent, text: cue.onTrack)
            signalRow(symbol: "arrow.triangle.2.circlepath", tint: DODColor.labelSecondary, text: cue.adjust)
        }
        .padding(DODSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
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
