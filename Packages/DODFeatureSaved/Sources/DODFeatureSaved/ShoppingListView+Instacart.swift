import DODNetworking
import SwiftUI

/// DUT-532 — the "Order on Instacart" CTA, split out of ``ShoppingListView`` to
/// keep that file under the 400-line cap. Part 1 of DUT-532: the app-side MVP
/// that ships DORMANT behind ``InstacartConfig/isConfigured`` (the live Worker +
/// IDP key are a separate backend step, mirroring how the SiwA revoke client
/// shipped ahead of its Worker).
extension ShoppingListView {

    /// The "Order on Instacart" toolbar CTA. Shown ONLY when the config gate is
    /// on (``InstacartConfig/isConfigured`` — the Worker is live) AND the
    /// still-need list is non-empty (nothing to order otherwise, mirroring the
    /// Share / Clear hide-while-empty posture). Production ships with the gate
    /// OFF, so the button is dormant until the backend lands.
    @ToolbarContentBuilder
    var instacartToolbar: some ToolbarContent {
        if instacartConfig.isConfigured && !viewModel.isEmpty {
            ToolbarItem(placement: .primaryAction) {
                if isCreatingInstacartLink {
                    ProgressView()
                        .accessibilityIdentifier("shopping-list-instacart-loading")
                        .accessibilityLabel("Creating Instacart order")
                } else {
                    Button {
                        orderOnInstacart()
                    } label: {
                        Label("Order on Instacart", systemImage: "cart.badge.plus")
                    }
                    .accessibilityIdentifier("shopping-list-instacart")
                    .accessibilityLabel("Order on Instacart")
                }
            }
        }
    }

    /// Map the still-need rows (the SAME subset the Share CTA uses:
    /// `visibleItems` minus checked, per ``ShoppingListFormatter/stillNeedLines(_:)``)
    /// to Instacart line-items, create the shopping-list page, and open its
    /// `products_link_url`. On any failure raise the failure alert; the list is
    /// never mutated. AC-39.12: the network is scoped to this opt-in CTA — the
    /// list build/persist paths still make zero network calls.
    func orderOnInstacart() {
        let lines = ShoppingListFormatter.stillNeedLines(viewModel)
        let lineItems = InstacartLineItemMapper.lineItems(from: lines)
        guard !lineItems.isEmpty else { return }
        isCreatingInstacartLink = true
        Task {
            defer { isCreatingInstacartLink = false }
            do {
                let url = try await instacart.createLink(
                    title: InstacartLineItemMapper.defaultTitle,
                    lineItems: lineItems
                )
                openURL(url)
            } catch {
                instacartFailed = true
            }
        }
    }
}
