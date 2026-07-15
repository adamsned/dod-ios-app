import DODDesignSystem
import DODSupport
import SwiftUI

/// The *fire* step of ``FirstCookoutView`` (DUT-239, DUT) — extracted from
/// `FirstCookoutView+Stages.swift` when the inline coal card pushed that file
/// over the SwiftLint `file_length` cap.
///
/// DUT: the step now **leads with the answer**. The reusable ``CoalAnswerCard``
/// is embedded at the top, seeded from the cookout, so a beginner sees the real
/// coal count + lid/bottom split WITHOUT leaving the flow (the old step led with
/// only a rough range + a button off to the coach). The Heat Coach CTA sits
/// below for deeper tuning (conditions / feel), so the card's number reads as a
/// starting point, never a hard rule.
extension FirstCookoutView {

    /// The embedded ``CoalAnswerCard`` at the top of the *fire* step — the real
    /// coal count + lid/bottom split, seeded from the cookout.
    var coalAnswerCard: some View {
        // Seed the split from the cookout: its oven diameter drives the total
        // (`diameter * 2`), and a lid-heavy baking style matches how the removed
        // `coalStartingPointNote` derived the range (`task: .bake`). No condition
        // inputs live on this step, so pass no cook-time / adjusted note — those
        // belong to the full coach, one tap away.
        let seed = HeatCoachSeed(
            fromRecipeTask: .bake,
            ovenDiameterInches: cookout.ovenDiameterInches,
            targetTemperatureF: cookout.ovenTempF
        )
        let split = DutchOvenHeatCoach.startingCoals(
            ovenDiameterInches: seed.ovenDiameterInches,
            style: seed.style
        )
        return CoalAnswerCard(split: split)
            .padding(.top, DODSpacing.xs)
    }

    /// DUT-239: below the embedded answer, the **Heat Coach** for deeper tuning.
    /// Coals are read by feel for the cook's own conditions (wind, weather,
    /// charcoal brand/size, oven size), so the card's number is a starting point
    /// and the coach is where a beginner dials it in.
    var heatCoachCallToAction: some View {
        VStack(spacing: DODSpacing.xs) {
            Text(
                "Every fire is different. Wind, weather, and your charcoal all change "
                    + "the count, so read the coals by feel instead of trusting one number."
            )
            .dodFont(DODType.body)
            .foregroundStyle(DODColor.labelSecondary)
            .multilineTextAlignment(.center)
            Button {
                showingHeatCoach = true
            } label: {
                Label("Open the Heat Coach", systemImage: "thermometer.sun.fill")
                    .frame(maxWidth: .infinity)
            }
            .dodProminentButton()
            .tint(DODColor.burntOrange)
        }
        .padding(.top, DODSpacing.xs)
    }
}
