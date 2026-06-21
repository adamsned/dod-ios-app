import Foundation

/// Pure, dependency-free **per-recipe charcoal converter** — turns a recipe's
/// oven temperature, the cook's oven diameter, and the cooking task into a
/// concrete briquette recommendation (total count, top/bottom split, and a
/// refresh cadence).
///
/// This is the calculator core of DUT-128 — the "manage the fire" step of the
/// *Your First Cookout* keystone. It answers the one question a recipe never
/// does: "I have a 12" oven and this says 350°F — **how many coals, where, and
/// when do I add more?**" The inline recipe card that surfaces this is a later
/// slice; this slice ships the pure logic + its L1 tests so the math is pinned
/// before any UI renders it.
///
/// Why this lives in `DODSupport` (not a feature package): it is a pure
/// value-type calculator (Foundation-only — no UI, no AVFoundation, no
/// network), the same seam pattern as ``DutchOvenHeatCoach``,
/// ``IngredientAisleClassifier``, and ``StepTimerParser``. Hosting it here lets
/// the recipe card render it, the unit suite exercise it on the macOS slice,
/// and any future surface (a Tools tab, an App Intent) reuse the same contract.
///
/// **Relationship to ``DutchOvenHeatCoach``:** the Heat Coach is the
/// standalone, condition-aware teaching screen (DUT-48). This converter is the
/// *per-recipe* shortcut — it takes the recipe's own target temperature and
/// task and hands back a single starting recommendation. Both share the brand's
/// `diameter × 2` baseline; this one layers a temperature adjustment and a
/// task-driven split on top.
///
/// Every number here is a **starting point, not a rule** — consistent with the
/// brand's published method, the caller frames the recommendation as a place to
/// begin, then adapt by feel.
///
/// Spec trace: US-50 / AC-50.1 (this pure converter, IMPLEMENTED). CL-201 (the
/// logic-core split — pure calculator ships ahead of the inline UI card).
/// T-807. Constitution §6 L1 mandate (every domain transform owns tests).
public enum CharcoalRecipeConverter {

    /// What the recipe is doing in the oven. Drives the top/bottom briquette
    /// split — the single lever that turns one coal count into the right heat
    /// *direction* for the dish.
    public enum CookTask: CaseIterable, Sendable, Hashable {
        /// Lid-heavy heat — breads, cobblers, cakes, casseroles. Browns the top
        /// without scorching the bottom (≈ ⅓ bottom / ⅔ top).
        case bake
        /// Even all-around heat — whole birds, roasts (≈ even top/bottom).
        case roast
        /// Bottom-led gentle heat — stews, beans, sauces held at a simmer
        /// (≈ ¾ bottom).
        case simmer
        /// Direct bottom heat — searing and frying in the oven's base
        /// (all bottom).
        case fry
    }

    // MARK: - Baseline & adjustment constants

    /// The temperature the `diameter × 2` baseline lands (the brand's steady
    /// baking band). Above/below this, briquettes are added/removed.
    private static let baselineTempF = 350

    /// Degrees Fahrenheit per adjustment step.
    private static let degreesPerStep = 25

    /// Briquettes added (or removed) per ``degreesPerStep`` away from the
    /// baseline — about ±2 coals per 25°F.
    private static let briquettesPerStep = 2

    /// Minutes between fresh-coal refreshes. A single steady cadence — the
    /// brand's "tend it sooner than you think" habit lands in the 45–60 min
    /// band; 45 keeps the cook ahead of a fade.
    private static let refreshMinutes = 45

    // MARK: - Recommend

    /// Recommend a charcoal layout for a recipe.
    ///
    /// **Total** starts from the brand's baseline rule — `diameter × 2`
    /// briquettes lands a ~350°F oven (12" → 24, 10" → 20, 14" → 28) — then
    /// adjusts by about **±2 briquettes per 25°F** away from ~350°F. A 12" oven
    /// at 400°F: `24 + 2 × ((400−350)/25) = 24 + 4 = 28`. The total never goes
    /// negative (clamped at 0).
    ///
    /// **Split** by ``CookTask``:
    /// - ``CookTask/bake`` — ⅓ bottom / ⅔ top (lid-heavy).
    /// - ``CookTask/roast`` — even (an odd total puts the extra on the bottom).
    /// - ``CookTask/simmer`` — ~¾ bottom.
    /// - ``CookTask/fry`` — all bottom.
    ///
    /// The split always satisfies `bottom + top == total`, and neither side is
    /// ever negative.
    ///
    /// **Refresh** is a steady ``refreshMinutes`` (45) — surface it as "add
    /// fresh coals about every 45 min", a starting cadence the cook tightens by
    /// feel.
    ///
    /// - Parameters:
    ///   - ovenTempF: The recipe's target oven temperature in °F.
    ///   - ovenDiameterInches: The cook's Dutch oven diameter in inches
    ///     (a non-positive value clamps the total to 0).
    ///   - task: What the recipe is doing — drives the top/bottom split.
    /// - Returns: A ``CharcoalRecommendation`` (total, bottom, top, refresh).
    public static func recommend(
        ovenTempF: Int,
        ovenDiameterInches: Int,
        task: CookTask
    ) -> CharcoalRecommendation {
        let total = totalBriquettes(ovenTempF: ovenTempF, ovenDiameterInches: ovenDiameterInches)
        let bottom = bottomBriquettes(total: total, task: task)
        let top = total - bottom
        return CharcoalRecommendation(
            totalBriquettes: total,
            bottom: bottom,
            top: top,
            refreshIntervalMinutes: refreshMinutes
        )
    }

    // MARK: - Total

    /// `diameter × 2` baseline, adjusted by ±``briquettesPerStep`` per
    /// ``degreesPerStep`` away from ``baselineTempF``, clamped at 0.
    ///
    /// The adjustment counts whole 25°F steps (integer division): 350–374°F is
    /// the same as 350°F (zero steps), 375°F is +1 step. Below baseline the
    /// step count is negative, so coals come off.
    private static func totalBriquettes(ovenTempF: Int, ovenDiameterInches: Int) -> Int {
        let baseTotal = max(0, ovenDiameterInches) * 2
        let steps = (ovenTempF - baselineTempF) / degreesPerStep
        let adjusted = baseTotal + steps * briquettesPerStep
        return max(0, adjusted)
    }

    // MARK: - Split

    /// How many of `total` briquettes go on the **bottom** for a given task.
    /// `top` is always `total - bottom`, so the split is exact and the
    /// invariant `bottom + top == total` holds by construction.
    private static func bottomBriquettes(total: Int, task: CookTask) -> Int {
        switch task {
        case .bake:
            // ⅓ bottom / ⅔ top — lid-heavy.
            return Int((Double(total) / 3.0).rounded())
        case .roast:
            // Even — odd total puts the extra on the bottom (the structural
            // side), so `bottom >= top` by at most one.
            return total - total / 2
        case .simmer:
            // ~¾ bottom — bottom-led gentle heat.
            return Int((Double(total) * 3.0 / 4.0).rounded())
        case .fry:
            // All bottom.
            return total
        }
    }
}

// MARK: - Value type

/// A per-recipe charcoal recommendation: the `totalBriquettes`, the
/// `bottom`/`top` split, and how often (`refreshIntervalMinutes`) to add fresh
/// coals. Always `bottom + top == totalBriquettes`, and no field is negative.
///
/// A named struct rather than a tuple so the contract is documented, evolvable,
/// and clear of the `large_tuple` lint rule.
public struct CharcoalRecommendation: Equatable, Sendable {
    /// Total briquettes for the cook (bottom + top).
    public let totalBriquettes: Int
    /// Briquettes under the oven.
    public let bottom: Int
    /// Briquettes on the lid.
    public let top: Int
    /// Minutes between fresh-coal refreshes (a starting cadence).
    public let refreshIntervalMinutes: Int

    public init(totalBriquettes: Int, bottom: Int, top: Int, refreshIntervalMinutes: Int) {
        self.totalBriquettes = totalBriquettes
        self.bottom = bottom
        self.top = top
        self.refreshIntervalMinutes = refreshIntervalMinutes
    }
}
