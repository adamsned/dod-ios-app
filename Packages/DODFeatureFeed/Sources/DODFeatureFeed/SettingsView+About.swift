import DODDesignSystem
import DODDomain
import DODNetworking
import SwiftUI

// The trailing About + Dev-Debug + version-footer sections, split out of
// `SettingsView.swift` so that host file stays under the SwiftLint 400-line
// `file_length` cap (the same partitioning rule the Bindings / Feedback splits
// follow). Behavior is unchanged — this is a mechanical move.
extension SettingsView {

    /// The "About Dutch Oven Daddy" section, the (dev-only) Dev Debug section,
    /// and the version footer, in top-to-bottom order.
    @ViewBuilder
    var aboutAndVersionSections: some View {
        // MARK: US-32 About + version

        Section {
            NavigationLink {
                AboutNedView()
            } label: {
                Text("About Dutch Oven Daddy")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.label)
            }
            .accessibilityIdentifier("settings-link-about")

            // DUT-157 — manual, always-available path to the App Store review page.
            rateAppLink

            // DUT-502 — a published Contact / Support affordance in-app
            // (Guideline 1.2). See `SettingsView+PolicyLinks.swift`.
            contactSupportLink
        }
        .listRowBackground(DODColor.surfaceElevated)

        devDebugSection  // ⚠️ DEV DEBUG — strip before public release

        Section {
            EmptyView()
        } footer: {
            Text(SettingsViewModel.versionFooter())
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityIdentifier("settings-version-footer")
                .devDebugFooterUnlock(unlocked: $devDebugUnlocked, forceShowOwnerUI: $devForceShowOwnerUI)
        }
        .listRowBackground(DODColor.surfaceElevated)
    }
}

extension SettingsView {
    /// WordPress category id of the "From Ned" announcements.
    static let announcementsCategoryID = 0  // DUT-1736 - placeholder value for testing

    /// Placeholder: loading the real count needs a network fetch, which is more state than this
    /// one-file change allows. Backed by `fromNedUnreadCount(in:tracker:)` once a list is loaded.
    var fromNedUnreadCount: Int { Self.fromNedUnreadCount(in: [], tracker: AnnouncementReadTracker()) }

    /// Badge math, pure so it is testable without rendering Settings.
    static func fromNedUnreadCount(in items: [Announcement], tracker: AnnouncementReadTracker) -> Int {
        tracker.unreadCount(in: items)
    }
}

/// The "From Ned" row in Settings. Its own view so it can own `@Environment(\.openURL)`
/// without adding a stored property to `SettingsView` (file_length cap).
struct FromNedSettingsLink: View {
    let unreadCount: Int
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationLink {
            AnnouncementsView(
                viewModel: AnnouncementsViewModel(
                    fetch: { try await WPRestClient().announcements(categoryID: SettingsView.announcementsCategoryID) }
                ),
                onOpenDeepLink: { link in
                    if case .shop(let url) = link { openURL(url) }
                    if case .recipe(let url) = link { openURL(url) }  // in-app recipe routing is a follow-up
                }
            )
        } label: {
            HStack {
                Text("From Ned").dodFont(DODType.body).foregroundStyle(DODColor.label)
                Spacer()
                if unreadCount > 0 {
                    Text("\(unreadCount)").accessibilityIdentifier("settings-from-ned-badge")
                }
            }
        }
        .accessibilityIdentifier("settings-link-from-ned")
    }
}
