import DODNetworking
import SwiftUI

/// DUT-532 — the "Order ingredients" grocery-ordering CTA, split out of
/// ``ShoppingListView`` to keep that file under the 400-line cap. Generalized
/// from the #402 Instacart-only MVP to a provider-agnostic hand-off: the app
/// POSTs `{ provider, title, line_items }` to a configured Worker and opens the
/// returned URL. Ships DORMANT behind ``GroceryOrderConfig/enabledProviders``
/// (the live Worker + provider keys are a separate backend step, mirroring how
/// the SiwA revoke client shipped ahead of its Worker).
extension ShoppingListView {

    /// The grocery-ordering toolbar CTA. Shown ONLY when at least one provider
    /// is enabled (``GroceryOrderConfig/enabledProviders`` — the Worker is live
    /// and providers are switched on) AND the still-need list is non-empty
    /// (nothing to order otherwise, mirroring the Share / Clear hide-while-empty
    /// posture). Production ships with no providers enabled, so this is dormant
    /// until the backend lands.
    ///
    /// One enabled provider → a single "Order on <provider>" button; multiple →
    /// an "Order ingredients" `Menu` listing each enabled provider.
    @ToolbarContentBuilder
    var groceryOrderToolbar: some ToolbarContent {
        let providers = groceryConfig.enabledProviders
        if !providers.isEmpty && !viewModel.isEmpty {
            ToolbarItem(placement: .primaryAction) {
                if isCreatingGroceryLink {
                    ProgressView()
                        .accessibilityIdentifier("shopping-list-grocery-loading")
                        .accessibilityLabel("Creating grocery order")
                } else if providers.count == 1, let provider = providers.first {
                    singleProviderButton(provider)
                } else {
                    multiProviderMenu(providers)
                }
            }
        }
    }

    /// The single-provider path: one tap orders on that provider directly.
    private func singleProviderButton(_ provider: GroceryProvider) -> some View {
        Button {
            orderIngredients(with: provider)
        } label: {
            Label("Order on \(provider.displayName)", systemImage: provider.systemImage)
        }
        .accessibilityIdentifier("shopping-list-grocery-\(provider.rawValue)")
        .accessibilityLabel("Order on \(provider.displayName)")
    }

    /// The multi-provider path: a menu offering each enabled provider.
    private func multiProviderMenu(_ providers: [GroceryProvider]) -> some View {
        Menu {
            ForEach(providers, id: \.self) { provider in
                Button {
                    orderIngredients(with: provider)
                } label: {
                    Label("Order on \(provider.displayName)", systemImage: provider.systemImage)
                }
                .accessibilityIdentifier("shopping-list-grocery-\(provider.rawValue)")
            }
        } label: {
            Label("Order ingredients", systemImage: "cart.badge.plus")
        }
        .accessibilityIdentifier("shopping-list-grocery-menu")
        .accessibilityLabel("Order ingredients")
    }

    /// Map the still-need rows (the SAME subset the Share CTA uses:
    /// `visibleItems` minus checked, per ``ShoppingListFormatter/stillNeedLines(_:)``)
    /// to grocery line-items — provider-agnostic — create the order for the
    /// chosen `provider`, and open its returned link. On any failure raise the
    /// failure alert; the list is never mutated. AC-39.12: the network is scoped
    /// to this opt-in CTA — the list build/persist paths still make zero network
    /// calls.
    func orderIngredients(with provider: GroceryProvider) {
        let lines = ShoppingListFormatter.stillNeedLines(viewModel)
        let lineItems = GroceryLineItemMapper.lineItems(from: lines)
        guard !lineItems.isEmpty else { return }
        isCreatingGroceryLink = true
        Task {
            defer { isCreatingGroceryLink = false }
            do {
                let url = try await grocery.createLink(
                    provider: provider,
                    title: GroceryLineItemMapper.defaultTitle,
                    lineItems: lineItems
                )
                openURL(url)
            } catch {
                groceryOrderFailed = true
            }
        }
    }
}
