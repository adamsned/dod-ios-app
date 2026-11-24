import DODDomain
import DODSupport
import SwiftUI

extension RecipeDetailView {
    /// DUT-968 — "Pass it down": share the recipe with the mentor's own notes.
    /// The toolbar passes `logs: []` until the dependencies expose all cook logs.
    func prepareLegacyHandoffShare(logs: [CookLogEntry]) {
        guard let recipe = viewModel.recipe else { return }
        let handoff = LegacyHandoffBuilder.build(
            recipe: recipe,
            logs: logs,
            fromName: "",
            message: "",
            coalTips: []
        )
        legacyHandoffText = LegacyHandoffText.render(handoff)
    }
}

extension View {
    /// DUT-968 — presents the iOS share sheet over the "Pass it down" text while
    /// it is non-nil; dismissing clears it. A no-op on the macOS `swift test` slice.
    @ViewBuilder
    func legacyHandoffShareSheet(_ text: Binding<String?>) -> some View {
        #if os(iOS)
        sheet(
            isPresented: Binding(
                get: { text.wrappedValue != nil },
                set: { if !$0 { text.wrappedValue = nil } }
            )
        ) {
            ShareSheet(items: [text.wrappedValue ?? ""])
        }
        #else
        self
        #endif
    }
}
