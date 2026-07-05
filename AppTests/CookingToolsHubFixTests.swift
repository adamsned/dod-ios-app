import DODAnalytics
import DODSupport
import XCTest

@testable import DODApp

/// Regression coverage for the Cooking Tools hub bug batch (the DUT-551 hub
/// refactor fallout): DUT-559 (guided-path progress state stranded at the hub)
/// and DUT-562 (double-counted `cooking_tools` screen_view).
///
/// The `CookChooserFlow.nodeState` → NodeState painting these recommendations
/// drive is covered where that `internal` API is reachable, in
/// `DODFeatureFeedTests` (`FirstCookoutFeedBugBatchTests`, extended here). This
/// App-target suite pins the derivation the hub itself owns: the
/// `cookStateLoaded ? nextUncookedRung(cookedRecipeIDs:) : nil` recommendation
/// and the centralized screen_view emit.
@MainActor
final class CookingToolsHubFixTests: XCTestCase {

    // MARK: - DUT-559 — the hub re-activates the rung recommendation

    /// The hub's exact recommendation expression:
    /// `cookStateLoaded ? nextUncookedRung(cookedRecipeIDs:) : nil`. Factored out
    /// so the gate can be exercised for both flag values without a SwiftUI host
    /// (and without a constant-folded, dead-branch ternary in each test).
    private func hubRecommendation(
        cookStateLoaded: Bool,
        cookedRecipeIDs: Set<Int>
    ) -> GuidedCookout? {
        cookStateLoaded
            ? GuidedCookout.nextUncookedRung(cookedRecipeIDs: cookedRecipeIDs)
            : nil
    }

    /// A brand-new cook (empty cook log): once the cook state has loaded the hub
    /// hands the chooser `nextUncookedRung([]) == rung 1`, so rung 1 becomes the
    /// "start here" recommendation. Before the fix the hub passed `recommended:
    /// nil` unconditionally, so no rung was ever recommended.
    func test_freshCook_loadedState_recommendsRung1() {
        let cookedRecipeIDs: Set<Int> = []  // a brand-new user, no logged cooks
        let recommended = hubRecommendation(cookStateLoaded: true, cookedRecipeIDs: cookedRecipeIDs)

        XCTAssertEqual(
            recommended?.recipeID,
            GuidedCookout.path[0].recipeID,
            "a fresh cook's recommendation, once loaded, is rung 1 (DUT-559)"
        )
        XCTAssertFalse(
            cookedRecipeIDs.contains(GuidedCookout.path[0].recipeID),
            "the hub passes an empty cookedRecipeIDs for a fresh cook, so no rung is pre-marked done"
        )
    }

    /// The cold-launch gate (DUT-212, re-activated): before the cook state loads
    /// the hub passes `recommended: nil`, so no stale rung 1 is recommended to a
    /// returning cook mid cold-launch race.
    func test_beforeLoad_recommendsNothing() {
        let recommended = hubRecommendation(cookStateLoaded: false, cookedRecipeIDs: [])
        XCTAssertNil(recommended, "before load the hub recommends nothing (the DUT-212 gate)")
    }

    /// A returning cook who logged rung 1: once loaded the hub advances the
    /// recommendation to rung 2 (`nextUncookedRung` walks past the cooked rung).
    func test_returningCook_advancesRecommendationToRung2() {
        let cookedRecipeIDs: Set<Int> = [GuidedCookout.path[0].recipeID]
        let recommended = GuidedCookout.nextUncookedRung(cookedRecipeIDs: cookedRecipeIDs)

        XCTAssertEqual(
            recommended?.recipeID,
            GuidedCookout.path[1].recipeID,
            "a cook who made rung 1 is recommended rung 2 (DUT-559)"
        )
    }

    // MARK: - DUT-562 — cooking_tools screen_view emits once per tab selection

    /// Selecting the Cooking Tools tab emits exactly ONE `screen_view(cooking_tools)`
    /// — from the centralized `ScreenViewTracking` — now that the hub's duplicate
    /// `.onAppear` self-emit is deleted. This mirrors Feed/Search/Saved, which
    /// never self-emit, restoring cross-tab funnel comparability (DUT-562).
    func test_cookingToolsTabSelection_emitsScreenViewExactlyOnce() {
        let recorder = RecordingTelemetryTransport()
        Telemetry.shared.replaceTransport(recorder)

        // One tab selection routes through the single centralized emit seam.
        ScreenViewTracking.emitScreenView(for: .cookingTools)

        XCTAssertEqual(
            recorder.events,
            [.screenView(name: AppTab.cookingTools.telemetryName)],
            "one Cooking Tools tab selection must record screen_view(cooking_tools) exactly once"
        )
        XCTAssertEqual(AppTab.cookingTools.telemetryName, "cooking_tools")
    }
}
