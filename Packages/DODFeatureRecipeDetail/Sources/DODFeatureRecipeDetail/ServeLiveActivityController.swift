import DODCookActivity
import Foundation

#if os(iOS)
import ActivityKit
#endif

/// DUT-980: drives the single multi-dish serve Live Activity. Platform-neutral so
/// callers and tests never import ActivityKit; the real `Activity` API lives only
/// in ``SystemServeLiveActivityController``.
@MainActor
public protocol ServeLiveActivityController: AnyObject {
    var isActive: Bool { get }
    var areActivitiesEnabled: Bool { get }
    func start(
        attributes: ServeActivityAttributes,
        initialState: ServeActivityAttributes.ContentState
    )
    func update(state: ServeActivityAttributes.ContentState)
    func end()
}

public enum ServeLiveActivityStale {
    /// Stale 60s after the serve moment; completed state never goes stale.
    public static func staleDate(for state: ServeActivityAttributes.ContentState) -> Date {
        state.isCompleted ? .distantFuture : state.serveAt.addingTimeInterval(60)
    }
}

@MainActor
public final class SystemServeLiveActivityController: ServeLiveActivityController {
    public init() {}

    #if os(iOS)
    private var activityStorage: Any?
    #endif

    public var isActive: Bool {
        #if os(iOS)
        return activityStorage != nil
        #else
        return false
        #endif
    }

    public var areActivitiesEnabled: Bool {
        #if os(iOS)
        if #available(iOS 16.1, *) { return ActivityAuthorizationInfo().areActivitiesEnabled }
        return false
        #else
        return false
        #endif
    }

    public func start(
        attributes: ServeActivityAttributes,
        initialState: ServeActivityAttributes.ContentState
    ) {
        #if os(iOS)
        guard #available(iOS 16.1, *), areActivitiesEnabled else { return }
        end()
        let content = ActivityContent(
            state: initialState,
            staleDate: ServeLiveActivityStale.staleDate(for: initialState)
        )
        activityStorage = try? Activity<ServeActivityAttributes>.request(
            attributes: attributes,
            content: content,
            pushType: nil
        )
        #endif
    }

    public func update(state: ServeActivityAttributes.ContentState) {
        #if os(iOS)
        guard #available(iOS 16.1, *),
            let activity = activityStorage as? Activity<ServeActivityAttributes>
        else { return }
        let content = ActivityContent(
            state: state,
            staleDate: ServeLiveActivityStale.staleDate(for: state)
        )
        Self.pushUpdate(activity: activity, content: content)
        #endif
    }

    public func end() {
        #if os(iOS)
        guard #available(iOS 16.1, *),
            let activity = activityStorage as? Activity<ServeActivityAttributes>
        else { return }
        activityStorage = nil
        Self.pushEnd(activity: activity)
        #endif
    }

    #if os(iOS)
    @available(iOS 16.1, *)
    nonisolated private static func pushUpdate(
        activity: Activity<ServeActivityAttributes>,
        content: ActivityContent<ServeActivityAttributes.ContentState>
    ) {
        let box = UncheckedSendableServeActivity(activity)
        Task { await box.activity.update(content) }
    }

    @available(iOS 16.1, *)
    nonisolated private static func pushEnd(activity: Activity<ServeActivityAttributes>) {
        let box = UncheckedSendableServeActivity(activity)
        Task { await box.activity.end(nil, dismissalPolicy: .immediate) }
    }

    /// `Activity` is documented as thread-safe but is not formally `Sendable`.
    @available(iOS 16.1, *)
    private struct UncheckedSendableServeActivity: @unchecked Sendable {
        let activity: Activity<ServeActivityAttributes>
        init(_ activity: Activity<ServeActivityAttributes>) { self.activity = activity }
    }
    #endif
}
