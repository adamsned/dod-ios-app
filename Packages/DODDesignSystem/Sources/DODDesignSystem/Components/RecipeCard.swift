import SwiftUI

/// Reusable list row for recipes. Generic over content — takes primitive
/// inputs so DesignSystem stays decoupled from Domain types (plan §1).
/// Feature modules (Feed, Categories, Search, Saved) provide thin adapters
/// from their domain item to `RecipeCard`.
///
/// Spec trace: spec.md AC-1.3, AC-2.3, AC-3.3, AC-5.3.
public struct RecipeCard: View {

    public let title: String
    public let excerpt: String
    public let heroImageURL: URL?
    public let totalTimeDisplay: String?

    public init(
        title: String,
        excerpt: String,
        heroImageURL: URL?,
        totalTimeDisplay: String? = nil
    ) {
        self.title = title
        self.excerpt = excerpt
        self.heroImageURL = heroImageURL
        self.totalTimeDisplay = totalTimeDisplay
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heroSection
            textSection
        }
        .background(DODColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DODSpacing.sm, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var heroSection: some View {
        ZStack(alignment: .topTrailing) {
            AsyncImage(url: heroImageURL) { phase in
                switch phase {
                case .empty:
                    LoadingSkeleton(cornerRadius: 0)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundStyle(DODColor.labelSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(DODColor.surface)
                @unknown default:
                    EmptyView()
                }
            }
            .frame(height: 200)
            .clipped()
            .accessibilityHidden(true)

            if let totalTimeDisplay {
                timeChip(totalTimeDisplay)
                    .padding(DODSpacing.xs)
            }
        }
    }

    private var textSection: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Text(title)
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.label)
                .lineLimit(2)
            Text(excerpt)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DODSpacing.md)
    }

    private func timeChip(_ display: String) -> some View {
        HStack(spacing: DODSpacing.xxs) {
            Image(systemName: "clock")
            Text(display)
        }
        .dodFont(DODType.caption)
        .foregroundStyle(DODColor.cream)
        .padding(.horizontal, DODSpacing.xs)
        .padding(.vertical, DODSpacing.xxs)
        .background(
            Capsule().fill(DODColor.castIronBrown.opacity(0.85))
        )
    }

    private var accessibilityLabel: String {
        if let totalTimeDisplay {
            "\(title). \(excerpt). \(totalTimeDisplay)."
        } else {
            "\(title). \(excerpt)."
        }
    }
}

#Preview("With time chip") {
    RecipeCard(
        title: "Garlic Butter Skillet Corn",
        excerpt: "An easy 15-minute side dish that pairs with everything.",
        heroImageURL: URL(string: "https://www.dutchovendaddy.com/wp-content/uploads/sample.jpg"),
        totalTimeDisplay: "15 min"
    )
    .padding(DODSpacing.md)
}

#Preview("No image") {
    RecipeCard(
        title: "Sourdough Bread",
        excerpt: "Crusty, chewy, slow-fermented.",
        heroImageURL: nil
    )
    .padding(DODSpacing.md)
}
