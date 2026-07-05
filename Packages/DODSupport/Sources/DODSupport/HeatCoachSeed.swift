import Foundation

/// A pre-answered starting point for the **Dutch Oven Heat Coach** screen
/// (DUT-584) — the values a caller hands the coach so it opens already showing
/// the right answer instead of the bare 12"/even default.
///
/// The per-recipe Heat Coach nudge (Recipe Detail) already derives a recipe's
/// heat profile (``RecipeHeatProfile/derive(from:)`` → oven temperature + task);
/// this type carries that intent into the coach: the oven diameter to preselect,
/// the cooking style to preselect, and the recipe's target temperature (for a
/// small "For this recipe at N°F" context line on the answer card).
///
/// Pure value type, Foundation-only — it lives in `DODSupport` so both the
/// recipe feature (which mints it) and the feed feature (which renders the
/// coach) share one contract without a cross-feature dependency, the same seam
/// as ``CoalSplit`` / ``CharcoalRecommendation``.
///
/// Spec trace: DUT-584 (recipe-prefill — the coach opens pre-answered).
public struct HeatCoachSeed: Equatable, Sendable {

    /// The oven diameter to preselect, in inches. From a recipe this is the same
    /// 12" the nudge assumed; standalone opens don't pass a seed at all.
    public let ovenDiameterInches: Int

    /// The cooking style to preselect, derived from the recipe's task
    /// (see ``init(fromRecipeTask:ovenDiameterInches:targetTemperatureF:)``).
    public let style: CookingStyle

    /// The recipe's target oven temperature in °F, for the answer card's context
    /// line. `nil` when the caller has no temperature to show.
    public let targetTemperatureF: Int?

    public init(
        ovenDiameterInches: Int,
        style: CookingStyle,
        targetTemperatureF: Int? = nil
    ) {
        self.ovenDiameterInches = ovenDiameterInches
        self.style = style
        self.targetTemperatureF = targetTemperatureF
    }

    /// Build a seed from a recipe's derived cook task, mapping the task to the
    /// coach's two-way cooking style so the coach opens consistent with the
    /// recipe nudge.
    ///
    /// The coach exposes only **Even** vs **Baking** (the lid/bottom split it
    /// teaches), while a recipe can derive four tasks. The mapping collapses
    /// them: only a lid-heavy ``CharcoalRecipeConverter/CookTask/bake`` maps to
    /// ``CookingStyle/baking``; every other task (roast, simmer, fry) is
    /// all-around or bottom-led heat, which the coach represents as
    /// ``CookingStyle/even``.
    public init(
        fromRecipeTask task: CharcoalRecipeConverter.CookTask,
        ovenDiameterInches: Int,
        targetTemperatureF: Int?
    ) {
        self.ovenDiameterInches = ovenDiameterInches
        self.style = Self.style(forRecipeTask: task)
        self.targetTemperatureF = targetTemperatureF
    }

    /// Map a recipe's four-way ``CharcoalRecipeConverter/CookTask`` onto the
    /// coach's two-way ``CookingStyle``: `.bake` → `.baking` (lid-heavy),
    /// everything else → `.even` (all-around / bottom-led).
    public static func style(forRecipeTask task: CharcoalRecipeConverter.CookTask) -> CookingStyle {
        switch task {
        case .bake:
            return .baking
        case .roast, .simmer, .fry:
            return .even
        }
    }
}
