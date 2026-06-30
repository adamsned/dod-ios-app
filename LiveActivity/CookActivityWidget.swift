import ActivityKit
import DODCookActivity
import DODDesignSystem
import SwiftUI
import WidgetKit

/// `ActivityConfiguration` for the Cook Mode timer Live Activity (US-11).
///
/// Wires ``CookActivityAttributes`` to the lock-screen and Dynamic Island
/// view layouts defined in the feature package (so the SnapshotTesting
/// suite can pin them without importing this extension). The
/// `ActivityConfiguration` is the only API surface here — everything
/// visual delegates to `CookActivity*View`.
@available(iOS 16.1, *)
struct CookActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CookActivityAttributes.self) { context in
            CookActivityLockScreenView(
                recipeTitle: context.attributes.recipeTitle,
                stepText: context.state.stepText,
                remainingSeconds: context.state.remainingSeconds,
                totalSeconds: context.attributes.totalSeconds,
                isPaused: context.state.isPaused,
                endDate: context.state.endDate
            )
            .padding(.horizontal, DODSpacing.sm)
            .padding(.vertical, DODSpacing.xs)
            // DUT-403: tapping the Live Activity opens the recipe the timer belongs to.
            .widgetURL(URL(string: "dod://recipe/\(context.attributes.recipeID)"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    CookActivityCompactLeadingView()
                        .padding(.leading, DODSpacing.xs)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CookActivityCompactTrailingView(
                        remainingSeconds: context.state.remainingSeconds,
                        endDate: context.state.endDate
                    )
                    .padding(.trailing, DODSpacing.xs)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    CookActivityLockScreenView(
                        recipeTitle: context.attributes.recipeTitle,
                        stepText: context.state.stepText,
                        remainingSeconds: context.state.remainingSeconds,
                        totalSeconds: context.attributes.totalSeconds,
                        isPaused: context.state.isPaused,
                        endDate: context.state.endDate
                    )
                }
            } compactLeading: {
                CookActivityCompactLeadingView()
            } compactTrailing: {
                CookActivityCompactTrailingView(
                    remainingSeconds: context.state.remainingSeconds,
                    endDate: context.state.endDate
                )
            } minimal: {
                CookActivityCompactLeadingView()
            }
        }
    }
}
