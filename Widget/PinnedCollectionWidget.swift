import DODDesignSystem
import DODSupport
import SwiftUI
import WidgetKit

struct PinnedCollectionWidget: Widget {
    static let kind = "PinnedCollectionWidget"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: PinnedCollectionWidgetIntent.self,
            provider: PinnedCollectionTimelineProvider()
        ) { entry in
            PinnedCollectionWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { DODColor.surfaceElevated }
                .dodWidgetSeasonedCastIron()
        }
        .configurationDisplayName("Pinned Collection")
        .description("Keep one of your cookbooks one tap away.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct PinnedCollectionWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PinnedCollectionEntry
    private static let collectionURL = URL(string: "dod://saved")!
    // opens the Saved tab, where the collection shelf lives

    var body: some View {
        switch entry.state {
        case .notConfigured: message("Pinned Collection", "Touch and hold, then Edit Widget to choose a collection.")
        case .missing: message("Collection not found", "It may have been deleted. Edit Widget to pick another.")
        case .empty(let name): message(name, "No recipes yet. Add some from a recipe's collection picker.")
        case .populated(let collection): populated(collection)
        }
    }

    private func message(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.headline)
            Text(body).font(.caption).foregroundStyle(DODColor.labelSecondary)
        }
        .padding(DODSpacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(Self.collectionURL)
    }

    private func populated(_ collection: PinnedCollectionsWidgetSnapshot.Collection) -> some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Link(destination: Self.collectionURL) {
                VStack(alignment: .leading, spacing: DODSpacing.xs) {
                    Text(collection.name)
                        .font(.headline)
                    Text("\(collection.totalCount) recipes")
                        .font(.caption2)
                        .foregroundStyle(DODColor.labelSecondary)
                }
            }

            recipeGrid(collection: collection)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(DODSpacing.sm)
        .widgetURL(Self.collectionURL)
    }

    private func recipeGrid(collection: PinnedCollectionsWidgetSnapshot.Collection) -> some View {
        if family == .systemLarge {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: DODSpacing.xs), count: 3),
                spacing: DODSpacing.xs
            ) {
                ForEach(Array(collection.recipes.prefix(6))) { recipe in
                    recipeLink(recipe: recipe)
                }
            }
        } else {
            HStack(spacing: DODSpacing.xs) {
                ForEach(Array(collection.recipes.prefix(3))) { recipe in
                    recipeLink(recipe: recipe)
                }
            }
        }
    }

    private func recipeLink(recipe: PinnedCollectionsWidgetSnapshot.Collection.Recipe) -> some View {
        Link(destination: recipe.deepLinkURL ?? Self.collectionURL) {
            VStack(spacing: DODSpacing.xs) {
                WidgetCard.Hero(
                    url: recipe.heroImageFilename.flatMap(WidgetImageBridge.fileURL(forFilename:))
                )
                .aspectRatio(1, contentMode: .fill)
                .clipShape(
                    RoundedRectangle(cornerRadius: DODRadius.widgetThumbnail, style: .continuous)
                )
                Text(recipe.title)
                    .font(.caption2)
                    .lineLimit(2)
            }
        }
        .accessibilityLabel("Recipe: \(recipe.title)")
    }
}

#Preview {
    PinnedCollectionWidgetEntryView(entry: .placeholder)
}
