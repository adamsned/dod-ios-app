import ActivityKit
import DODCookActivity
import DODDesignSystem
import SwiftUI
import WidgetKit

/// DUT-980: unified multi-dish Live Activity counting down to one serve moment.
@available(iOS 16.1, *)
struct ServeActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ServeActivityAttributes.self) { context in
            ServeActivityLockScreenView(title: context.attributes.title, state: context.state)
                .padding(.horizontal, DODSpacing.sm)
                .padding(.vertical, DODSpacing.xs)
                .widgetURL(URL(string: "dod://feed"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    ServeActivityLockScreenView(title: context.attributes.title, state: context.state)
                }
            } compactLeading: {
                CookActivityCompactLeadingView()
            } compactTrailing: {
                Text(timerInterval: Date()...max(context.state.serveAt, Date()), countsDown: true)
                    .monospacedDigit().frame(maxWidth: 60)
            } minimal: {
                Text(timerInterval: Date()...max(context.state.serveAt, Date()), countsDown: true)
                    .monospacedDigit().frame(maxWidth: 48)
            }
        }
    }
}
