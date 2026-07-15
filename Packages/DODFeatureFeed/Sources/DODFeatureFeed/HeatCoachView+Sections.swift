import DODDesignSystem
import DODSupport
import SwiftUI

// The answer + setup + conditions compositions for ``HeatCoachView`` (DUT-48;
// DUT-584 answer-first; v2 de-listed redesign), split out of `HeatCoachView.swift`
// so each file stays under the `file_length` cap. The cook-by-feel cues and the
// coal-management / wind reference live in `HeatCoachView+Feel`.
//
//   - ``answerCard`` — the answer first: the reusable ``CoalAnswerCard`` (the
//     coal-split diagram under the "starting point, then cook by feel" framing +
//     optional recipe context line), fed the condition-adjusted split.
//   - ``primaryInputsCard`` — the two minimal inputs (Oven Size + Cooking Style),
//     laid out with air rather than stacked rows behind a divider.
//   - ``conditionsGroup`` — the optional collapsed "Adjust for Conditions"
//     expander (elevation / air temp / wind + the adjustment notes).

extension HeatCoachView {

    // MARK: - The answer, first + visual

    var answerCard: some View {
        // The reusable ``CoalAnswerCard`` (also embedded in the First Cookout fire
        // step), fed the CONDITION-adjusted split so a hot/cold/windy day moves the
        // starting point (DUT-600) and the always-shown elevation cook-time line
        // (DUT-601). The "Already adjusted…" note (DUT-653) shows only when the
        // conditions have actually shifted the count off the plain starting point.
        CoalAnswerCard(
            split: coachModel.adjustedCoalSplit,
            conditionsAdjusted: coachModel.conditionCoalDelta != 0...0,
            cookTimeLine: coachModel.elevationCookTimeLine,
            recipeContextLine: recipeContextLine
        )
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
        VStack(alignment: .leading, spacing: DODSpacing.lg) {
            // Oven Size — the current size reads large on the left, the − / +
            // control sits inline on the right. Just the number + inches; the
            // "Oven Size" caption already says what it is (no "Diameter" clutter).
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                    Text("Oven Size")
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.labelSecondary)
                    Text("\(ovenDiameterInches)\"")
                        .dodFont(DODType.displayMedium)
                        .foregroundStyle(DODColor.label)
                }
                Spacer()
                Stepper("Oven Size", value: $ovenDiameterInches, in: sizeRange, step: 2)
                    .labelsHidden()
                    .tint(DODColor.accent)
                    .accessibilityIdentifier("heat-coach-oven-size")
            }

            // Cooking Style — the two pills with the split note as one quiet line
            // right beneath, at the point of choice.
            VStack(alignment: .leading, spacing: DODSpacing.xs) {
                Text("Cooking Style")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
                accentSelector(
                    selection: $style,
                    options: [(.even, "Even"), (.baking, "Baking")],
                    accessibilityID: "heat-coach-style"
                )
                Text(coachModel.styleNote)
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("heat-coach-style-note")
            }
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

            // Label left, switch flush to the same trailing edge as the
            // Elevation stepper's − / +. A default full-width Toggle drifted its
            // switch past that edge and clipped the card; a labels-hidden Toggle
            // pushed right by a Spacer sits inside the padding and lines up.
            HStack(spacing: DODSpacing.sm) {
                Text("Windy Day")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.label)
                    .accessibilityHidden(true)
                Spacer(minLength: DODSpacing.sm)
                Toggle("Windy Day", isOn: $windy)
                    .labelsHidden()
                    .tint(DODColor.accent)
                    .accessibilityIdentifier("heat-coach-wind")
            }

            let notes = adjustmentNotes(coachModel)
            if !notes.isEmpty {
                Divider().overlay(DODColor.surfaceDivider)
                VStack(alignment: .leading, spacing: DODSpacing.sm) {
                    Text("What Changes")
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.labelSecondary)
                        .textCase(.uppercase)
                    // Plain, well-spaced lines — no per-line bullet dot. The
                    // caption above already frames them as the adjustments.
                    ForEach(notes, id: \.self) { note in
                        Text(note)
                            .dodFont(DODType.body)
                            .foregroundStyle(DODColor.label)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
        if let elevationCoalNote = coachModel.elevationCoalNote { notes.append(elevationCoalNote) }
        if let elevationNote = coachModel.elevationNote { notes.append(elevationNote) }
        notes.append(coachModel.replenishNote)
        if let windCoalNote = coachModel.windCoalNote { notes.append(windCoalNote) }
        if let windNote = coachModel.windNote { notes.append(windNote) }
        return notes
    }
}
