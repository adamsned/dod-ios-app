import SwiftUI

extension View {
    /// DUT-84 — the offline "remove this download?" confirmation, shared by the
    /// recipe-detail download toggle (`RecipeDetailViewModel`) and the Saved-tab
    /// "Remove Download" context action (`SavedViewModel`) so the copy and
    /// button roles stay identical across both surfaces.
    ///
    /// Presented only when the device is **offline**: removing a download with
    /// no network strands the recipe — its text and hero image can't be
    /// re-fetched until service returns — so the user confirms first. Online,
    /// the caller removes immediately without presenting this (re-downloading
    /// is a tap away). A native `alert` is deliberate: a destructive
    /// "are you sure?" is exactly the system-alert idiom, and "Keep Download"
    /// takes the bold `.cancel` slot so the safe choice is the default.
    ///
    /// The caller owns the presented binding and the removal action; this
    /// helper only standardizes the presentation.
    public func offlineRemoveDownloadAlert(
        isPresented: Binding<Bool>,
        onRemove: @escaping () -> Void
    ) -> some View {
        alert("You're offline", isPresented: isPresented) {
            Button("Remove Download", role: .destructive, action: onRemove)
            Button("Keep Download", role: .cancel) {}
        } message: {
            Text("Removing this download means you won't be able to open this recipe until you're back online.")
        }
    }
}
