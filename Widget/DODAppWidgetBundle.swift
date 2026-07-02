import SwiftUI
import WidgetKit

/// Extension entry point. WidgetKit discovers widgets by enumerating
/// types declared on the bundle's `body` property. Four widget kinds:
/// ``FeaturedRecipeWidget`` (US-9, home-screen small / medium / large),
/// ``SavedRecipesWidget`` (US-17, home-screen small / medium / large),
/// ``LatestRecipeLockScreenWidget`` (US-22, lock-screen
/// `.accessoryRectangular`), and ``SavedLockScreenWidget`` (US-22 /
/// CL-168, lock-screen `.accessoryCircular` Saved shortcut).
/// Order matters for the widget gallery — featured stays first to
/// preserve existing user muscle memory; saved appears second; the
/// lock-screen kinds go last so existing installs see the same first-
/// two ordering they had before T-370.
///
/// The daily ``CookingTipWidget`` ships `.accessoryInline` (DUT-454) plus
/// `.systemSmall` + `.systemMedium` home-screen cards (DUT-459). (`.systemLarge`
/// shipped in CL-165; `.accessoryCircular` shipped as a Saved shortcut per
/// CL-168.)
///
/// Spec trace: US-9, US-17 (AC-17.1), US-22 (AC-22.1, AC-22.7); DUT-454, DUT-459.
@main
struct DODAppWidgetBundle: WidgetBundle {
    var body: some Widget {
        FeaturedRecipeWidget()
        SavedRecipesWidget()
        LatestRecipeLockScreenWidget()
        SavedLockScreenWidget()
        CookingTipWidget()
    }
}
