import DODDesignSystem
import DODSupport
import SwiftUI

/// T-912 / DUT-551 (CL-306) — the per-recipe **Heat Coach nudge**, extracted
/// into its own file so `RecipeDetailView.swift` stays under the SwiftLint
/// `file_length` cap (mirrors `RecipeDetailView+Blurb.swift` / `+Toolbar.swift`).
///
/// A de-emphasized card, shown right below the Cook Now CTA, that turns the
/// recipe's own oven temperature into a *rough* starting coal count for a 12"
/// Dutch oven, then points the cook at the standalone Heat Coach to dial it in
/// by feel. Purposefully framed as a starting point, never a hard rule —
/// echoing the First Cookout coal note's wording/tone.
extension RecipeDetailView {

    /// The nudge, shown only when we're confident: the recipe carries an
    /// explicit-unit oven temperature (``RecipeHeatProfile/derive(from:)`` is
    /// non-nil) AND has parsed instructions AND the host wired the hub route
    /// (`openHeatCoach != nil`). Any miss → an `EmptyView`, so a recipe with no
    /// temperature (or a preview / host without hub routing) shows nothing.
    @ViewBuilder
    var heatCoachNudge: some View {
        if let openHeatCoach, let derived = heatCoachDerived {
            let recommendation = CharcoalRecipeConverter.recommend(
                ovenTempF: derived.ovenTempF,
                ovenDiameterInches: Self.heatCoachOvenDiameterInches,
                task: derived.task
            )
            // A loose ±2 range so it reads as a place to begin, not a precise
            // rule — same framing as the First Cookout coal note.
            let low = max(recommendation.totalBriquettes - 2, 0)
            let high = recommendation.totalBriquettes + 2

            VStack(alignment: .leading, spacing: DODSpacing.sm) {
                HStack(spacing: DODSpacing.xs) {
                    Image(systemName: "thermometer.medium")
                        .foregroundStyle(DODColor.burntOrange)
                        .accessibilityHidden(true)
                    Text("Heat Coach")
                        .dodFont(DODType.bodyEmphasized)
                        .foregroundStyle(DODColor.label)
                }
                Text(
                    "About \(low)-\(high) coals for a "
                        + "\(Self.heatCoachOvenDiameterInches)-inch oven at "
                        + "\(derived.ovenTempF)°F. Dial it in for your conditions."
                )
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)

                Button {
                    // DUT-584 — open the coach pre-answered from this recipe: 12"
                    // (the nudge's own assumption), style derived from the recipe's
                    // task, and the recipe's target °F for the answer's context line.
                    openHeatCoach(
                        HeatCoachSeed(
                            fromRecipeTask: derived.task,
                            ovenDiameterInches: Self.heatCoachOvenDiameterInches,
                            targetTemperatureF: derived.ovenTempF
                        )
                    )
                } label: {
                    Text("Open Heat Coach")
                        .dodFont(DODType.bodyEmphasized)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DODColor.burntOrange)
                .accessibilityIdentifier("recipe-heat-coach-open")
            }
            .padding(DODSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                // CL-304 — card tier: DODRadius.standard pinned to live iOS
                // .insetGrouped. De-emphasized fill so it reads as a hint.
                RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                    .fill(DODColor.surfaceElevated)
            )
            .padding(.horizontal, DODSpacing.md)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("recipe-heat-coach-nudge")
        }
    }

    /// The confident heat profile for the loaded recipe, or `nil` when the nudge
    /// should hide: the recipe must be loaded, carry parsed instructions, AND
    /// yield an explicit-unit oven temperature (``RecipeHeatProfile/derive(from:)``
    /// non-nil). Splitting this out of the `@ViewBuilder`'s condition keeps that
    /// `if let` a single line — so SwiftLint (`opening_brace`, same-line brace)
    /// and swift-format (`AddLines`, own-line brace for a wrapped condition) don't
    /// disagree over a multiline `if let`.
    private var heatCoachDerived: RecipeHeatProfile.Derived? {
        guard let recipe = viewModel.recipe, !recipe.instructions.isEmpty else { return nil }
        return RecipeHeatProfile.derive(from: recipe)
    }

    /// The oven diameter the nudge assumes when it runs the charcoal
    /// recommendation — 12", the same default the standalone Heat Coach uses.
    /// The copy states the assumption so the cook can adjust for a different oven.
    static var heatCoachOvenDiameterInches: Int { 12 }
}
