import DODDesignSystem
import SwiftUI

/// **Daddy Mode (Phase 1, cosmetic).** The honest placeholder presented from the
/// owner-only compose button in the Feed header. Shown as a `.sheet`, so it
/// dismisses with a top-right "Done" (nav convention for sheets).
///
/// Phase 1 is display-only: there's no post-authoring surface yet. App-exclusive
/// posts arrive with the backend that can accept + attribute them; until then
/// this screen just explains that, doing nothing.
struct ComposePlaceholderView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DODSpacing.md) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 48))
                        .foregroundStyle(DODColor.burntOrange)
                        .accessibilityHidden(true)
                        .padding(.top, DODSpacing.xl)

                    Text("Compose a Post")
                        .dodFont(DODType.displayMedium)
                        .foregroundStyle(DODColor.labelStrong)
                        .multilineTextAlignment(.center)

                    Text(
                        """
                        Writing app-exclusive posts lands with the backend that \
                        can publish them. This entry point is here now so it's \
                        ready to go. It doesn't post anything yet.
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
            .navigationTitle("New Post")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("compose-placeholder-done")
                }
            }
        }
        .accessibilityIdentifier("compose-placeholder")
    }
}

#Preview {
    ComposePlaceholderView()
}
