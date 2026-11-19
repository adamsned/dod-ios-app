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
            VStack(spacing: 0) {
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
                if state.isCompleted { CookActivityBuzzerButtons() }
            }
            .padding(.horizontal, DODSpacing.sm)
            .padding(.vertical, DODSpacing.xs)
        }
    }
}

/// DUT-988 — one-tap buzzer actions. Only shown on the completed (buzzer) card.
@available(iOS 17.0, *)
private struct CookActivityBuzzerButtons: View {
    var body: some View {
        HStack(spacing: DODSpacing.sm) {
            Button(intent: PulledItIntent()) {
                Text("Pulled It").frame(maxWidth: .infinity)
            }
            .tint(DODColor.accent)
            Button(intent: SnoozeTimerIntent()) {
                Text("2 More Min").frame(maxWidth: .infinity)
            }
            .tint(DODColor.burntOrange)
        }
        .buttonStyle(.borderedProminent)
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
                    VStack(spacing: 0) {
                        CookActivityLockScreenView(
                            recipeTitle: context.attributes.recipeTitle,
                            stepText: context.state.stepText,
                            remainingSeconds: context.state.remainingSeconds,
                            totalSeconds: context.attributes.totalSeconds,
                            isPaused: context.state.isPaused,
                            endDate: context.state.endDate,
                            isCompleted: context.state.isCompleted
                        )
                        if context.state.isCompleted { CookActivityBuzzerButtons() }
                    }
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
