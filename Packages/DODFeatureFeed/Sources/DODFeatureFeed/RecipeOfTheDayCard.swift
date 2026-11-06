import DODDesignSystem
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
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                heroImageLayer
                textOverlay
            }
            .clipShape(RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                    .stroke(DODColor.burntOrange, lineWidth: 2)
            )
        }
        .buttonStyle(.dodPressable)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Recipe of the Day: \(item.title). \(Self.hook(for: item))")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("dod.feed.recipe-of-the-day")
    }
}

extension RecipeOfTheDayCard {
    fileprivate var heroImageLayer: some View {
        ReliableImage(url: item.heroImage) { phase in
            switch phase {
            case .empty:
                LoadingSkeleton(cornerRadius: 0)
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure:
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundStyle(DODColor.labelSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DODColor.surface)
            }
        }
        .frame(height: 220)
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

extension RecipeOfTheDayCard {
    fileprivate var textOverlay: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xxs) {
            Text("RECIPE OF THE DAY")
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.burntOrange)
            Text(item.title)
                .dodFont(DODType.displayMedium)
                .foregroundStyle(DODColor.label)
                .lineLimit(2)
            Text(Self.hook(for: item))
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
                .lineLimit(2)
        }
        .padding(DODSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DODColor.surfaceElevated.opacity(0.92))
    }
}
