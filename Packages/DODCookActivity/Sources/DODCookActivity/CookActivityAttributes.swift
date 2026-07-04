import Foundation

#if os(iOS)
import ActivityKit
#endif

/// Live Activity payload for an in-progress Cook Mode timer (US-11).
///
/// `attributes` carries the immutable per-activity context — the recipe
/// title, its WP id, and the original duration in seconds so the Lock
/// Screen / Dynamic Island UI can render a fixed progress arc. The
/// `ContentState` carries the per-tick mutable bits we re-publish each
/// second while the timer is running.
///
/// `ActivityAttributes` is only present on Apple platforms that ship
/// ActivityKit (iOS 16.1+). On macOS hosts — which the feature package
/// still builds against for `swift test` — we expose a parallel pure-value
/// type so the rest of the codebase (the view model, the controller
/// abstraction, the tests) can refer to ``CookActivityAttributes`` and
/// ``CookActivityAttributes/ContentState`` without conditional spelling.
///
/// Spec trace: spec.md US-11, AC-11.1..AC-11.4.
public struct CookActivityAttributes: Codable, Hashable, Sendable {

    public struct ContentState: Codable, Hashable, Sendable {
        public var remainingSeconds: Int
        public var stepText: String
        public var isPaused: Bool
        /// DUT-218: wall-clock instant the timer finishes, set while running so
        /// the Lock Screen / Dynamic Island render a self-updating
        /// `Text(timerInterval:countsDown:)` that ticks WITHOUT per-second pushes
        /// (those stop when the app is backgrounded, which froze the countdown).
        /// `nil` while paused or for a non-live render (snapshots) → the views
        /// fall back to the static `remainingSeconds` snapshot.
        public var endDate: Date?
        /// DUT-490 / DUT-491: first-class "done" flag for the DUT-354 buzzer
        /// linger. When set, the card is a completed timer (00:00) rather than a
        /// paused one: the view renders "Done" (not "Paused") and the controller
        /// stamps a far-future stale date so the single completed push outlives
        /// the linger instead of dimming after ~15s. Defaults to `false` and
        /// decodes to `false` for older payloads (Codable back-compat).
        public var isCompleted: Bool

        public init(
            remainingSeconds: Int,
            stepText: String,
            isPaused: Bool,
            endDate: Date? = nil,
            isCompleted: Bool = false
        ) {
            self.remainingSeconds = remainingSeconds
            self.stepText = stepText
            self.isPaused = isPaused
            self.endDate = endDate
            self.isCompleted = isCompleted
        }

        private enum CodingKeys: String, CodingKey {
            case remainingSeconds, stepText, isPaused, endDate, isCompleted
        }

        /// DUT-490 / DUT-491: tolerate payloads encoded before `isCompleted`
        /// existed — a card in flight across an app update decodes with
        /// `isCompleted == false` rather than failing the whole state.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            remainingSeconds = try container.decode(Int.self, forKey: .remainingSeconds)
            stepText = try container.decode(String.self, forKey: .stepText)
            isPaused = try container.decode(Bool.self, forKey: .isPaused)
            endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
            isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        }
    }

    public var recipeTitle: String
    public var recipeID: Int
    public var totalSeconds: Int

    public init(recipeTitle: String, recipeID: Int, totalSeconds: Int) {
        self.recipeTitle = recipeTitle
        self.recipeID = recipeID
        self.totalSeconds = totalSeconds
    }
}

#if os(iOS)
@available(iOS 16.1, *)
extension CookActivityAttributes: ActivityAttributes {}
#endif
