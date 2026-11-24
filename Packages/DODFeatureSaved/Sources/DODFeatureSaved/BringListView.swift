import DODDesignSystem
import DODSupport
import SwiftUI

enum BringListPresentation {
    static func displayName(_ category: BringListCategory) -> String {
        switch category {
        case .ovens: "Dutch Ovens"
        case .fuel: "Coals & Fuel"
        case .tools: "Tools"
        case .transport: "Table & Transport"
        case .other: "Other Gear"
        }
    }

    static func glyph(_ category: BringListCategory) -> String {
        switch category {
        case .ovens: "frying.pan"
        case .fuel: "flame"
        case .tools: "wrench.and.screwdriver"
        case .transport: "shippingbox"
        case .other: "bag"
        }
    }

    static func rowLabel(_ item: BringListItem) -> String {
        item.quantity > 1 ? "\(item.quantity) x \(item.name)" : item.name
    }
}

struct BringListGearHeader: View {
    let category: BringListCategory

    var body: some View {
        Label {
            Text(BringListPresentation.displayName(category))
                .dodFont(DODType.bodyEmphasized)
                .foregroundStyle(DODColor.label)
        } icon: {
            Image(systemName: BringListPresentation.glyph(category))
                .foregroundStyle(DODColor.accent)
        }
        .textCase(nil)
        .accessibilityAddTraits(.isHeader)
    }
}

struct BringListView: View {
    @Binding var list: BringList

    var body: some View {
        List {
            ForEach(list.grouped(), id: \.category) { group in
                Section {
                    ForEach(group.items) { item in
                        Button {
                            list.togglePacked(id: item.id)
                        } label: {
                            Label(
                                BringListPresentation.rowLabel(item),
                                systemImage: item.isPacked ? "checkmark.circle.fill" : "circle"
                            )
                        }
                        .accessibilityValue(item.isPacked ? "Packed" : "Not packed")
                    }
                } header: {
                    BringListGearHeader(category: group.category)
                }
            }
        }
        .navigationTitle("The Bring List")
    }
}
