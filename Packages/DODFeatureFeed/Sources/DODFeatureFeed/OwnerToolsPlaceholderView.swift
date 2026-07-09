import DODDesignSystem
import SwiftUI

/// **Daddy Mode (Phase 1, cosmetic).** The honest placeholder destination behind
/// the owner-only "Daddy's Tools" row in Settings. Pushed via `NavigationLink`,
/// so it dismisses with the system back chevron (nav convention for pushes).
///
/// Phase 1 is display-only: there are no real moderation tools yet. This screen
/// says so plainly rather than pretending — the actual tools unlock once the
/// secure backend is live and can verify the owner server-side (a later phase).
struct OwnerToolsPlaceholderView: View {

    var body: some View {
        ScrollView {
            VStack(spacing: DODSpacing.md) {
                Image(systemName: "key.shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(DODColor.burntOrange)
                    .accessibilityHidden(true)
                    .padding(.top, DODSpacing.xl)

                Text("Daddy's Tools")
                    .dodFont(DODType.displayMedium)
                    .foregroundStyle(DODColor.labelStrong)
                    .multilineTextAlignment(.center)

                Text(
                    """
                    This is where owner tools like comment moderation will live. \
                    They stay switched off until the secure backend is live and \
                    can confirm it's really you. Nothing here does anything yet.
                    """
                )
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DODSpacing.md)
            }
            .frame(maxWidth: .infinity)
            .padding(DODSpacing.md)
        }
        .background(DODColor.surface)
        .navigationTitle("Daddy's Tools")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .accessibilityIdentifier("daddys-tools-placeholder")
    }
}

#Preview {
    NavigationStack {
        OwnerToolsPlaceholderView()
    }
}
