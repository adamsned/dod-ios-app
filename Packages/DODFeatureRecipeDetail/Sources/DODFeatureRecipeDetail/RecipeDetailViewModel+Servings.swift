import Foundation

// US-31 servings-scaler action methods, extracted from
// `RecipeDetailViewModel.swift` so that file stays under the SwiftLint
// 400-line file_length cap after the DUT-315 recipe-swap re-sync landed
// (the same partitioning rule `+Fetch` / `+Blurb` / `+CommentSubmit` follow).
// The stored state these mutate (`userServings`, `didSyncServingsToSource`,
// `lastSyncedSourceServings`) lives on the host and is `internal`-widened so
// this sibling-file extension can reach it.
//
// Spec trace: US-31 AC-31.3, AC-31.7, AC-31.8; DUT-357; DUT-315.

extension RecipeDetailViewModel {

    /// DUT-677 — true once a *real* `recipeYield` has parsed. The resync guards
    /// must distinguish "the yield is genuinely known" from "still the not-yet-
    /// parsed sentinel", and `sourceServings` collides the two: a recipe whose
    /// real yield equals ``defaultServings`` (4) is byte-identical to the
    /// fallback. Gate on the optional (`recipe?.servings`), which is `nil` only
    /// while unparsed, instead of on the collided `Int`.
    private var hasParsedYield: Bool { recipe?.servings != nil }

    /// Adjust the user's serving count (clamped to ``userServingsRange``).
    /// Called from the stepper's `value` binding. AC-31.7: changing the
    /// serving count never clears ``checkedIngredientIDs`` — the user's
    /// in-progress check state survives a scale.
    public func setUserServings(_ count: Int) {
        userServings = clampToRange(count)
    }

    /// Sync ``userServings`` to source on the first `.ready` only (DUT-357) — a
    /// late refresh must not clobber the user's deliberate manual stepper choice.
    public func resetServingsToSourceIfFirstLoad() {
        guard !didSyncServingsToSource else { return }
        didSyncServingsToSource = true
        // DUT-471: record the baseline UNCONDITIONALLY — even when this first
        // `.ready` carries the default yield (the list item hadn't hydrated a
        // real `recipeYield` yet). Leaving `lastSyncedSourceServings` nil here
        // permanently defeats the DUT-315 resync (its `guard let last` returns),
        // so when the full detail later lands a real yield the stepper never
        // syncs and ingredients silently scale at default/N. Pinning the
        // baseline to the default makes that later real yield differ → resync.
        lastSyncedSourceServings = sourceServings
        // DUT-677: skip only when NO real yield has parsed yet (sentinel),
        // not when the parsed yield merely happens to equal ``defaultServings``.
        guard hasParsedYield else { return }
        // Do NOT clamp here (AC-31.3): the default sync must land exactly on
        // the source yield so `servingsScaleFactor` is 1.0 until the user
        // deliberately changes it. `userServingsRange` (1...24) is a UI
        // affordance for the stepper's OWN taps (AC-31.2) — `parseServings`
        // guarantees any parsed `recipeYield` is already `> 0`, so this can
        // never assign an invalid value, only one the stepper's range caps
        // at. A large-batch recipe (e.g. `recipeYield: 30`, plausible for a
        // crowd/potluck dutch-oven recipe) previously got silently clamped to
        // 24 here, making `servingsScaleFactor` 24/30 = 0.8 on first load —
        // every ingredient quantity rendered 20% under what the recipe
        // actually calls for, with zero user interaction. The Stepper still
        // reads out of `servingsRange` for +/- taps and its own
        // `setUserServings` clamp; only the initial default-sync skips it.
        userServings = sourceServings
    }

    /// DUT-315 — re-sync the stepper when a *different* recipe (new source
    /// yield) is swapped in after `.ready`, with no loadState transition to
    /// re-fire the one-shot. Keyed on a CHANGED yield so unrelated re-renders
    /// (same yield) never clobber a manual edit; defers to the one-shot for the
    /// first sync (`lastSyncedSourceServings == nil`).
    public func resyncServingsIfSourceYieldChanged() {
        // DUT-677: gate on a genuinely parsed yield, not on the collided Int —
        // a recipe whose real yield is ``defaultServings`` (4) must still resync.
        guard hasParsedYield else { return }
        guard let last = lastSyncedSourceServings, sourceServings != last else { return }
        lastSyncedSourceServings = sourceServings
        // Do NOT clamp — see the matching note in
        // `resetServingsToSourceIfFirstLoad()`; this resync must land the
        // scale factor back on 1.0 for the newly-swapped recipe too.
        userServings = sourceServings
    }

    /// Clamp `count` to ``userServingsRange``. Centralized so the setter
    /// and the source-sync path agree on bounds.
    func clampToRange(_ count: Int) -> Int {
        min(max(count, userServingsRange.lowerBound), userServingsRange.upperBound)
    }
}
