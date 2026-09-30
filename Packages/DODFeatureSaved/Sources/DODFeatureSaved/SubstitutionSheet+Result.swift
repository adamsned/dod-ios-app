import DODDesignSystem
import DODIntelligence
import SwiftUI

// v2 on-device AI — the substitution sheet's RESULT rendering, split out of
// `SubstitutionSheet.swift` to keep that file under the SwiftLint 400-line cap.
// Renders the three verdicts (options to pick from, "leave it out", "not a good
// fit"), fronted by the prominent allergy banner when the reason was an allergy.
extension SubstitutionSheet {

    /// The loaded result: an optional allergy banner, then the verdict body, then
    /// the always-on general disclaimer.
    @ViewBuilder
    func resultBody(for result: SubstitutionResult) -> some View {
        VStack(alignment: .leading, spacing: DODSpacing.md) {
            if state.reason?.isAllergy == true {
                allergyBanner
            }

            switch result.verdict {
            case .options(let options):
                optionsBody(options)
            case .omit(let note):
                verdictCard(
                    icon: "checkmark.seal",
                    title: "You Can Leave This Out",
                    note: note,
                    identifier: "shopping-substitution-omit-card"
                )
            case .notAGoodFit(let note):
                verdictCard(
                    icon: "exclamationmark.circle",
                    title: "This Recipe May Not Be a Good Fit",
                    note: note,
                    identifier: "shopping-substitution-notfit-card"
                )
            }

            generalDisclaimer
        }
    }

    // MARK: - Options (req: multiple choices)

    /// The pickable list of substitutes. One option still renders as a single
    /// selected row so Apply has something to act on.
    @ViewBuilder
    private func optionsBody(_ options: [IngredientSubstitution]) -> some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Text(options.count > 1 ? "Pick a Substitute" : "Suggested Substitute")
                .dodFont(DODType.bodyEmphasized)
                .foregroundStyle(DODColor.label)

            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                Button {
                    selectOption(index)
                } label: {
                    optionRow(option, selected: index == optionSelection)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("shopping-substitution-option-\(index)")
            }
        }
    }

    private func optionRow(_ option: IngredientSubstitution, selected: Bool) -> some View {
        HStack(alignment: .top, spacing: DODSpacing.sm) {
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selected ? DODColor.accent : DODColor.labelSecondary)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                Text(option.substitute)
                    .dodFont(DODType.bodyEmphasized)
                    .foregroundStyle(DODColor.label)
                    .fixedSize(horizontal: false, vertical: true)
                Text(option.note)
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.labelSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(DODSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DODColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                .strokeBorder(selected ? DODColor.accent : Color.clear, lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - Omit / not-a-good-fit (reqs: omission, not a good fit, allowed to say no)

    /// A single-message result card (used for both the "leave it out" and the
    /// "not a good fit" verdicts).
    private func verdictCard(icon: String, title: String, note: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Label {
                Text(title)
                    .dodFont(DODType.bodyEmphasized)
                    .foregroundStyle(DODColor.label)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(DODColor.accent)
            }
            Text(note)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DODSpacing.md)
        .background(DODColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Allergy banner (req: allergy gets the strongest emphasis)

    /// The prominent red safety banner shown above an Allergy result. Paired with
    /// the stronger `.warning` haptic fired by the sheet on load.
    private var allergyBanner: some View {
        HStack(alignment: .top, spacing: DODSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DODColor.warning)
                .font(.system(size: 22, weight: .semibold))
            VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                Text("Allergy Safety")
                    .dodFont(DODType.bodyEmphasized)
                    .foregroundStyle(DODColor.warning)
                Text(
                    "Confirm every ingredient and its label yourself before cooking. An AI suggestion is not a check for your allergen."
                )
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DODSpacing.md)
        .background(DODColor.warning.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                .strokeBorder(DODColor.warning, lineWidth: 1.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("shopping-substitution-allergy-banner")
    }
}
