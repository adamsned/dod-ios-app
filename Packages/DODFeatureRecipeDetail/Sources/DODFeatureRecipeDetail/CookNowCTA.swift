import DODDesignSystem
import SwiftUI

/// Primary call-to-action that opens Cook Mode (spec AC-7.1).
///
/// Visually distinct, full-width burnt-orange button with a chef-hat icon
/// so it's the obvious "do something" affordance on the detail screen and
/// reachable without scrolling on iPhone 13 baseline.
struct CookNowCTA: View {

    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DODSpacing.sm) {
                Image(systemName: "frying.pan.fill")
                    .font(.title3)
                    .accessibilityHidden(true)
                Text("Cook Now")
                    .dodFont(DODType.bodyEmphasized)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(DODColor.cream)
            .padding(.horizontal, DODSpacing.md)
            .padding(.vertical, DODSpacing.sm)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                    .fill(DODColor.accent)
                    .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Cook Now")
        .accessibilityHint("Opens a hands-free cooking surface with step-by-step instructions.")
        .accessibilityAddTraits(.isButton)
        .padding(.horizontal, DODSpacing.md)
    }
}
