import ActivityKit
import DODCookActivity
import DODDesignSystem
import SwiftUI
import WidgetKit

/// DUT-991: picks the StandBy face vs. the Lock Screen card.
@available(iOS 16.1, *)
private struct CookActivityPresentationView: View {
    let attributes: CookActivityAttributes
    let state: CookActivityAttributes.ContentState
    @Environment(\.isActivityFullscreen) private var isFullscreen

    var body: some View {
        if isFullscreen {
            CookActivityStandByView(
                recipeTitle: attributes.recipeTitle,
                model: CookActivityStandByModel(state: state)
            )
        } else {
            CookActivityLockScreenView(
                recipeTitle: attributes.recipeTitle,
                stepText: state.stepText,
                remainingSeconds: state.remainingSeconds,
                totalSeconds: attributes.totalSeconds,
                isPaused: state.isPaused,
                endDate: state.endDate,
                isCompleted: state.isCompleted,
                coachNudge: state.coachNudge
            )
            .padding(.horizontal, DODSpacing.sm)
            .padding(.vertical, DODSpacing.xs)
        }
    }
}

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
            CookActivityPresentationView(attributes: context.attributes, state: context.state)
                .widgetURL(
                    context.attributes.recipeID > 0
                        ? URL(string: "dod://recipe/\(context.attributes.recipeID)")
                        : URL(string: "dod://feed")
                )
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    CookActivityCompactLeadingView()
                        .padding(.leading, DODSpacing.xs)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CookActivityCompactTrailingView(
                        remainingSeconds: context.state.remainingSeconds,
                        endDate: context.state.endDate,
                        isPaused: context.state.isPaused,
                        isCompleted: context.state.isCompleted
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
                        endDate: context.state.endDate,
                        isCompleted: context.state.isCompleted
                    )
                }
            } compactLeading: {
                CookActivityCompactLeadingView()
            } compactTrailing: {
                CookActivityCompactTrailingView(
                    remainingSeconds: context.state.remainingSeconds,
                    endDate: context.state.endDate,
                    isPaused: context.state.isPaused,
                    isCompleted: context.state.isCompleted
                )
            } minimal: {
                // DUT-694: the minimal pill is the only always-on glimpse of a
                // running timer — show the live (self-ticking) countdown instead
                // of the static pan so the collapsed slot reads as a timer. The
                // compact-trailing view already shrinks `H:MM:SS` to fit one line.
                CookActivityCompactTrailingView(
                    remainingSeconds: context.state.remainingSeconds,
                    endDate: context.state.endDate,
                    isPaused: context.state.isPaused,
                    isCompleted: context.state.isCompleted
                )
            }
        }
    }
}
