import DODDesignSystem
import SwiftUI

// DUT-160 — the Privacy Dashboard's category row cell + the per-bucket deep-link
// controls, split out of `PrivacyDashboardView.swift` for `file_length` hygiene
// (the same partitioning the Settings surface uses). The controls deep-link to
// the existing screens rather than duplicating them: the On Device bucket routes
// to the Shopping List + Saved surfaces, the iCloud bucket pops back to the
// Settings list where the iCloud Sync toggle lives, and the Public bucket opens
// the blog (comments/ratings are managed on the website).
extension PrivacyDashboardView {

    // MARK: - Category row

    /// One tappable category row: title + trailing location/count on top, a
    /// chevron that flips when open, and the sentence-case explanation revealed
    /// below on tap (the AC's "one-tap plain-language explanation").
    @ViewBuilder
    func dataRow(_ row: PrivacyDataRow) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { toggleExpanded(row.id) }
        } label: {
            VStack(alignment: .leading, spacing: DODSpacing.xs) {
                HStack(spacing: DODSpacing.sm) {
                    Text(row.title)
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.label)
                    Spacer(minLength: DODSpacing.xs)
                    Text(row.detail)
                        .dodFont(DODType.detail)
                        .foregroundStyle(DODColor.labelSecondary)
                    Image(systemName: isExpanded(row.id) ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(DODColor.labelSecondary)
                }
                if isExpanded(row.id) {
                    Text(row.explanation)
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.labelSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("privacy-dashboard-row-\(row.id)")
        .accessibilityElement(children: .combine)
        .accessibilityHint(isExpanded(row.id) ? "Hides the explanation." : "Shows a plain-language explanation.")
    }

    // MARK: - Per-bucket deep-link controls

    /// The deep-link control(s) for a bucket, wired only where a real control
    /// exists (the AC's "where one exists").
    @ViewBuilder
    func bucketControls(_ bucket: PrivacyBucket) -> some View {
        switch bucket.id {
        case .onDevice:
            routeButton(
                title: "Open Shopping List",
                identifier: "privacy-dashboard-open-shopping-list"
            ) {
                openRoute("dod://shopping-list")
            }
            routeButton(
                title: "See Saved Recipes",
                identifier: "privacy-dashboard-open-saved"
            ) {
                openRoute("dod://saved")
            }
        case .iCloud:
            routeButton(
                title: "Manage iCloud Sync",
                identifier: "privacy-dashboard-manage-icloud"
            ) {
                popToSettings()
            }
        case .publicBlog:
            blogLink
        }
    }

    /// An accent-tinted action row (matches the "Clear Cached Recipe Images"
    /// button style in the Data & Privacy section).
    @ViewBuilder
    private func routeButton(
        title: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier(identifier)
    }

    /// External link to the blog, where comments + ratings are managed (there is
    /// no in-app comment-management surface). Routes through the tree-wide
    /// `openURL` override; drops the row if the literal will not parse.
    @ViewBuilder
    private var blogLink: some View {
        if let url = URL(string: SettingsViewModel.blogHomeURLString) {
            Link(destination: url) {
                Text("View on the Blog")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("privacy-dashboard-open-blog")
            .accessibilityLabel("View on the blog, opens in browser")
        }
    }
}
