import DODDomain
import Foundation

/// DUT-1002: timed day-before checklist built from the kitchen-prep steps of a split cook.
public enum HomePrepChecklist {
    public struct Item: Sendable, Equatable, Identifiable {
        public let id: UUID
        public let step: Int
        public let text: String
        /// nil when the step text has no parseable duration.
        public let minutes: Int?
    }

    public struct Checklist: Sendable, Equatable {
        public let items: [Item]
        /// Sum of known step minutes.
        public let totalMinutes: Int
        public var isEmpty: Bool { items.isEmpty }
    }

    public static func build(from recipe: Recipe) -> Checklist {
        let home = SplitCookStageClassifier.partition(recipe.instructions).home
        let items = home.map { step -> Item in
            let secs = StepTimerParser.firstDuration(in: step.text).map { Int($0.components.seconds) }
            return Item(id: step.id, step: step.step, text: step.text, minutes: secs.map { max(1, $0 / 60) })
        }
        return Checklist(items: items, totalMinutes: items.compactMap(\.minutes).reduce(0, +))
    }
}
