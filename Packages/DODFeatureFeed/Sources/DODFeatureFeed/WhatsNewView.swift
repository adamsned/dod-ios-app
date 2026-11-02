import DODDesignSystem
import DODNetworking
import SwiftUI

/// The "What's New" sheet for one release (DUT-174 part 5). Pure UI: the
/// presenting callers fire analytics, not this view.
public struct WhatsNewView: View {
    let release: ChangelogRelease
    let onDismiss: () -> Void

    public init(release: ChangelogRelease, onDismiss: @escaping () -> Void) {
        self.release = release
        self.onDismiss = onDismiss
    }

    /// Caps bullets at 5 so a long WP entry can't overflow the sheet.
    nonisolated static func visibleBullets(_ bullets: [String]) -> [String] {
        Array(bullets.prefix(5))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DODSpacing.md) {
                if let url = release.heroImageURL {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Color.clear.frame(height: 0)
                    }
                    .accessibilityHidden(true)
                }
                Text("What's New")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
                Text(release.title)
                    .dodFont(DODType.displayMedium)
                    .accessibilityAddTraits(.isHeader)
                ForEach(Array(Self.visibleBullets(release.bullets).enumerated()), id: \.offset) { _, bullet in
                    Label(bullet, systemImage: "checkmark.circle.fill")
                        .dodFont(DODType.body)
                }
                Button(action: onDismiss) {
                    Text("Got it")
                        .dodFont(DODType.bodyEmphasized)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DODSpacing.md)
                        .background(DODColor.accent, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(Color.white)
                }
                .accessibilityIdentifier("whats-new-got-it")
            }
            .padding(DODSpacing.md)
        }
        .background(DODColor.surface)
        .accessibilityIdentifier("whats-new-sheet")
    }
}
