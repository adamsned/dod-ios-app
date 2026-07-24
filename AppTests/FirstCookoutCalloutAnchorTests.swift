import XCTest

@testable import DODApp

/// The App-level half of the callout's anchoring contract.
///
/// `DODDesignSystem`'s `TabBarCalloutTailTests` proves the SHAPE aims correctly
/// given a fraction. This proves the App hands it the RIGHT fraction — i.e. that
/// `toolsTabTailFraction` actually resolves to the Tools tab in the real tab-bar
/// order. Neither half is meaningful alone: a perfect shape pointed at the wrong
/// fraction is still a callout aimed at the wrong tab.
final class FirstCookoutCalloutAnchorTests: XCTestCase {

    /// Tools is currently 3rd of 4 (Recipes, Saved, Tools, Search), so an evenly
    /// distributed bar centers it at (2 + 0.5) / 4.
    func test_toolsTabTailFraction_matchesToolsPositionInTheTabBar() {
        XCTAssertEqual(RootView.toolsTabTailFraction, 0.625, accuracy: 0.0001)
    }

    /// The fraction must be DERIVED from `AppTab.allCases` — the single source of
    /// truth for tab-bar order — not hard-coded. Recompute it independently from
    /// the enum: if someone reorders the tabs, this stays true while a literal
    /// `0.625` in the implementation would silently start aiming at Saved.
    func test_tailFractionTracksTheTabOrder_ratherThanAHardCodedOffset() {
        let tabs = AppTab.allCases
        let index = try? XCTUnwrap(tabs.firstIndex(of: .cookingTools))
        let expected = (CGFloat(index ?? 0) + 0.5) / CGFloat(tabs.count)
        XCTAssertEqual(RootView.toolsTabTailFraction, expected, accuracy: 0.0001)
    }

    /// The aim must land strictly inside the Tools slot, not merely near it: within
    /// half a tab-width of the tab's center. This is what makes the fraction
    /// approach defensible despite the tab bar's inset on iOS 26.
    func test_tailFractionLandsInsideTheToolsSlot() {
        let tabs = AppTab.allCases
        let slot = 1.0 / CGFloat(tabs.count)
        guard let index = tabs.firstIndex(of: .cookingTools) else {
            return XCTFail("Tools must be in the tab bar.")
        }
        let toolsCenter = (CGFloat(index) + 0.5) * slot
        XCTAssertLessThan(
            abs(RootView.toolsTabTailFraction - toolsCenter),
            slot / 2,
            "The tail must aim within the Tools slot."
        )
    }

    /// The review/UI-test override must be OFF unless a launch flag turns it on —
    /// otherwise a production build would re-nudge cooks who already dismissed it.
    func test_forceFlagDefaultsOff_soRealDismissalsAreHonoured() {
        XCTAssertFalse(DODEnvironment.forceFirstCookoutCallout)
    }
}
