import DODDomain
import DODSupport
import Foundation

/// DUT-968 — assembles the "Pass it down" payload for one recipe.
enum LegacyHandoffBuilder {
    static func build(
        recipe: Recipe,
        logs: [CookLogEntry],
        fromName: String,
        message: String,
        coalTips: [String]
    ) -> LegacyHandoff {
        // Only this recipe's logs, newest first.
        let mine = logs.filter { $0.recipeID == recipe.id }
            .sorted { $0.cookedAt > $1.cookedAt }
        return LegacyHandoff(
            recipeID: recipe.id,
            recipeTitle: recipe.title,
            recipeURL: recipe.canonicalURL,
            fromName: fromName,
            message: message,
            notes: mine.compactMap(\.note),
            coalTips: coalTips,
            photoLocalIDs: mine.compactMap(\.photoLocalID)
        )
    }
}
