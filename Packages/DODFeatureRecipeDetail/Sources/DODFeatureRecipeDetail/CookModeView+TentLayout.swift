import DODDesignSystem
import SwiftUI

extension CookModeView {

    /// DUT-1017 — half-open (tent) posture: step + timer above the hinge,
    /// ingredients below it. The 1pt divider marks where the hinge sits.
    var tentLayout: some View {
        VStack(spacing: 0) {
            VStack(spacing: DODSpacing.sm) {
                ScrollView {
                    stepBody.padding(.top, DODSpacing.md)
                }
                toolDock
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            ingredientsList
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityIdentifier("cook-mode-tent-layout")
    }
}
