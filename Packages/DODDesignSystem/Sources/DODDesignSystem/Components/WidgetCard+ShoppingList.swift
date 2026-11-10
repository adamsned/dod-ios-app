import SwiftUI

extension WidgetCard {

    public enum ShoppingListLayout {
        public static let mediumRows = 3
        public static let largeRows = 5
        public static func progressText(remaining: Int, total: Int) -> String { "\(remaining) of \(total) left" }
    }

    public struct ShoppingListHeader: View {
        public let name: String
        public let remaining: Int
        public let total: Int
        public init(name: String, remaining: Int, total: Int) {
            self.name = name
            self.remaining = remaining
            self.total = total
        }
        public var body: some View {
            HStack {
                Text(name)
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(DODColor.burntOrange)
                    .textCase(.uppercase)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(ShoppingListLayout.progressText(remaining: remaining, total: total))
                    .font(.caption2)
                    .foregroundStyle(DODColor.label)
            }
        }
    }

    /// Generic over the checkbox so the widget can pass a `Button(intent:)`.
    public struct ShoppingListRow<Checkbox: View>: View {
        public let text: String
        public let checkbox: Checkbox
        public init(text: String, @ViewBuilder checkbox: () -> Checkbox) {
            self.text = text
            self.checkbox = checkbox()
        }
        public var body: some View {
            HStack(spacing: DODSpacing.xs) {
                checkbox
                Text(text).font(.system(.footnote, weight: .semibold)).foregroundStyle(DODColor.label).lineLimit(2)
                Spacer(minLength: 0)
            }
        }
    }

    public struct ShoppingListComplete: View {
        public var body: some View {
            VStack {
                Text("All items checked! 🎉")
            }
        }
    }  // complete state

    public struct ShoppingListNoList: View {
        public var body: some View {
            VStack {
                Text("No shopping list")
                Text("Add ingredients from a recipe")
            }
        }
    }  // placeholder state
}

#Preview("Shopping List Header") {
    WidgetCard.ShoppingListHeader(name: "My List", remaining: 2, total: 7)
        .frame(width: 338, height: 20)
}

#Preview("Shopping List Row") {
    WidgetCard.ShoppingListRow(text: "1 cup flour") {
        Image(systemName: "checkmark.square")
            .foregroundStyle(DODColor.labelSecondary)
    }
    .frame(width: 338, height: 40)
}

#Preview("Shopping List Complete") {
    WidgetCard.ShoppingListComplete()
        .frame(width: 338, height: 158)
}

#Preview("Shopping List No List") {
    WidgetCard.ShoppingListNoList()
        .frame(width: 338, height: 158)
}
