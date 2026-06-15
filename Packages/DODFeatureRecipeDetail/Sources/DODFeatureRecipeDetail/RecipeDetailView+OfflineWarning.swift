import DODDesignSystem
import SwiftUI

/// DUT-84 — attaches the offline remove-download confirmation to
/// ``RecipeDetailView``. Extracted into its own `ViewModifier` (and file) so the
/// alert's binding and action don't push `RecipeDetailView`'s already
/// near-cap `type_body_length` over the limit. `@Bindable` gives the shared
/// ``SwiftUI/View/offlineRemoveDownloadAlert(isPresented:onRemove:)`` a two-way
/// binding to the view model's `showOfflineRemoveDownloadWarning` flag.
struct OfflineRemoveDownloadWarningModifier: ViewModifier {
    @Bindable var viewModel: RecipeDetailViewModel

    func body(content: Content) -> some View {
        content.offlineRemoveDownloadAlert(
            isPresented: $viewModel.showOfflineRemoveDownloadWarning,
            onRemove: { Task { await viewModel.confirmRemoveDownload() } }
        )
    }
}
