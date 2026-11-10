import DODDesignSystem
import DODSupport
import SwiftUI
import WidgetKit

struct ShoppingListWidget: Widget {
    static let kind = ShoppingListWidgetBridge.kind  // "ShoppingListWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: ShoppingListTimelineProvider()) { entry in
            ShoppingListWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { DODColor.surfaceElevated }
                .dodWidgetSeasonedCastIron()
        }
        .configurationDisplayName("Shopping List")
        .description("Check off your next grocery items right from the Home Screen.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
