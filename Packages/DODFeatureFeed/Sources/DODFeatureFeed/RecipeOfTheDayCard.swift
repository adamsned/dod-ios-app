import DODDomain
import SwiftUI

/// DUT-117 — the pinned "Recipe of the Day" hero card at the top of the feed.
struct RecipeOfTheDayCard: View {
    let item: RecipeListItem
    let onTap: () -> Void

    nonisolated static let fallbackHook = "Today's pick from the kitchen"
    nonisolated static let maxHookLength = 90

    /// First sentence of the excerpt, trimmed. Falls back to a fixed line when the
    /// excerpt is empty or longer than `maxHookLength`.
    nonisolated static func hook(for item: RecipeListItem) -> String {
        let trimmed = item.excerpt.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstSentence =
            trimmed
            .split(separator: ".", maxSplits: 1, omittingEmptySubsequences: true)
            .first.map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !firstSentence.isEmpty, firstSentence.count <= maxHookLength else {
            return fallbackHook
        }
        return firstSentence
    }

    var body: some View {
        Text(item.title)
    }
}
