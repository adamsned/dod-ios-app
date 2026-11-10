import AppIntents
import DODDesignSystem
import DODSupport
import SwiftUI
import WidgetKit

struct ShoppingListWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ShoppingListEntry

    private var maxRows: Int {
        family == .systemLarge
            ? WidgetCard.ShoppingListLayout.largeRows
            : WidgetCard.ShoppingListLayout.mediumRows
    }

    var body: some View {
        Group {
            if let state = entry.state {
                if state.unchecked.isEmpty {
                    WidgetCard.ShoppingListComplete()  // all items checked
                } else {
                    listBody(state)
                }
            } else {
                WidgetCard.ShoppingListNoList()  // no active list
            }
        }
        .widgetURL(URL(string: "dod://shopping-list"))
    }

    private func listBody(_ state: ShoppingListWidgetState) -> some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            WidgetCard.ShoppingListHeader(name: state.listName, remaining: state.remaining, total: state.total)
            ForEach(Array(state.unchecked.prefix(maxRows))) { item in
                WidgetCard.ShoppingListRow(text: item.text) {
                    Button(intent: ToggleShoppingItemIntent(itemID: item.id)) {
                        Image(systemName: "circle").foregroundStyle(DODColor.burntOrange)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(DODSpacing.sm)
    }
}
