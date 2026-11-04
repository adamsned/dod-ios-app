import DODDesignSystem
import DODDomain
import SwiftUI

public struct AnnouncementsView: View {
    @State var viewModel: AnnouncementsViewModel
    let onOpenDeepLink: (Announcement.DeepLink) -> Void

    public init(viewModel: AnnouncementsViewModel, onOpenDeepLink: @escaping (Announcement.DeepLink) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onOpenDeepLink = onOpenDeepLink
    }

    public var body: some View {
        Group {
            switch viewModel.state {
            case .empty:
                Text("Nothing new from Ned yet.")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.label)
                    .accessibilityIdentifier("from-ned-empty")
            case .offline:
                Text("You're offline. Pull to retry.")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.label)
                    .accessibilityIdentifier("from-ned-offline")
            default:
                list
            }
        }
        .navigationTitle("From Ned")
        .task {
            await viewModel.load()
            viewModel.markOpened()
        }
        .refreshable { await viewModel.load() }
    }

    private var list: some View {
        List(viewModel.items) { item in
            VStack(alignment: .leading, spacing: 8) {
                if let url = item.imageURL {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Color.clear.frame(height: 1)
                    }
                }
                Text(item.title)
                    .dodFont(DODType.heading)
                    .foregroundStyle(DODColor.labelStrong)
                // Body is Markdown; Text(.init(String)) uses LocalizedStringKey rendering.
                Text(.init(item.bodyMarkdown))
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.label)
                Text(item.publishedAt, style: .date)
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
                if let link = item.deepLink {
                    Button("Open") {
                        viewModel.didTapDeepLink(item)
                        onOpenDeepLink(link)
                    }
                    .accessibilityIdentifier("from-ned-link-\(item.id)")
                }
            }
        }
        .accessibilityIdentifier("from-ned-list")
    }
}
