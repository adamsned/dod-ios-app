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
                // DUT-572 / CL-312 — renamed "Cook Now" → "Cook Mode" with a
                // subtitle in a leading VStack so the CTA reads as an editorial
                // entry point, not a bare button. Title Case control label
                // (§10.2); sentence-case subtitle.
                VStack(alignment: .leading, spacing: 0) {
                    Text("Cook Mode")
                        .dodFont(DODType.bodyEmphasized)
                    Text("Step-by-step, spoken instructions.")
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.cream.opacity(0.85))
                }
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
                // CL-304 / DUT-537 — button tier: tappable CTA → Capsule pill.
                Capsule(style: .continuous)
                    .fill(DODColor.accent)
                    .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Cook Mode")
        .accessibilityHint("Opens a hands-free cooking surface with step-by-step instructions.")
        .accessibilityAddTraits(.isButton)
        .padding(.horizontal, DODSpacing.md)
    }
}
