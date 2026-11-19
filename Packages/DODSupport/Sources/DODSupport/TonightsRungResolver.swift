import Foundation

/// DUT-989 — picks tonight's single Control Center action.
public enum TonightsRungResolver {
    public struct InProgress: Equatable, Sendable {
        public let recipeID: Int
        public let title: String
        public let stepNumber: Int

        public init(recipeID: Int, title: String, stepNumber: Int) {
            self.recipeID = recipeID
            self.title = title
            self.stepNumber = stepNumber
        }
    }

    /// An in-progress cook wins (`.resume`). Otherwise re-offer the most recently
    /// cooked recipe (`.cook`). Returns nil when there is neither, or ids are <= 0.
    public static func resolve(
        inProgress: InProgress?,
        cookLog: [CookLogEntry],
        now: Date
    ) -> TonightsRungSnapshot? {
        if let inProgress, inProgress.recipeID > 0 {
            return TonightsRungSnapshot(
                writtenAt: now,
                kind: .resume,
                recipeID: inProgress.recipeID,
                title: inProgress.title,
                stepNumber: max(1, inProgress.stepNumber)
            )
        }
        guard let last = cookLog.filter({ $0.recipeID > 0 }).max(by: { $0.cookedAt < $1.cookedAt }) else {
            return nil
        }
        return TonightsRungSnapshot(
            writtenAt: now,
            kind: .cook,
            recipeID: last.recipeID,
            title: last.recipeTitle
        )
    }
}
