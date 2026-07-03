import DODDesignSystem
import SwiftUI

// DUT-461 — the Cooking Tip in-app popup (DUT-457), presented as a styled card
// over a dimmed scrim instead of a system alert. Extracted from `RootView.swift`
// for the SwiftLint file_length cap.
extension RootView {

    /// Dimmed scrim + the centered ``TipDialogCard``. Tap the scrim or the card's
    /// X to dismiss. Shown from `body`'s `.overlay(if: showTipDialog)`.
    var cookingTipOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { showTipDialog = false }
                .accessibilityHidden(true)
            TipDialogCard(tip: tipDialogText) { showTipDialog = false }
                .frame(maxWidth: 320)
                .padding(DODSpacing.lg)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
    }
}
