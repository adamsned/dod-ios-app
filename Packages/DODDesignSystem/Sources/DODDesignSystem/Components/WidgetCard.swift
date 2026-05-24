import SwiftUI

/// Visual components used by the home-screen widget (spec.md US-9). Defined
/// in DODDesignSystem so they can be snapshot-tested via the existing
/// SnapshotTesting harness (constitution §6 L4) without dragging WidgetKit
/// into the test target. The widget extension hosts these inside its
/// `TimelineEntryView`; this module knows nothing about WidgetKit itself.
///
/// All variants accept a single ``WidgetCard.Content`` struct so the call
/// site is identical to the production code path.
public enum WidgetCard {

    /// Plain-old-data input for the widget card variants. Mirrors the
    /// subset of `WidgetSnapshot.Entry` (DODSupport) that the views render.
    public struct Content: Equatable, Sendable {
        public let title: String
        public let excerpt: String
        public let heroImageURL: URL?
        public let totalTimeDisplay: String?

        public init(
            title: String,
            excerpt: String,
            heroImageURL: URL? = nil,
            totalTimeDisplay: String? = nil
        ) {
            self.title = title
            self.excerpt = excerpt
            self.heroImageURL = heroImageURL
            self.totalTimeDisplay = totalTimeDisplay
        }
    }

    // MARK: - Small

    /// Square small-widget layout: hero behind a bottom gradient + title.
    public struct Small: View {

        public let content: Content

        public init(content: Content) {
            self.content = content
        }

        public var body: some View {
            ZStack(alignment: .bottomLeading) {
                Hero(url: content.heroImageURL)

                VStack {
                    Spacer(minLength: 0)
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.0),
                            Color.black.opacity(0.45),
                            Color.black.opacity(0.75),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 110)
                }

                VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                    if let totalTime = content.totalTimeDisplay {
                        TimeChip(text: totalTime)
                    }
                    Text(content.title)
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .padding(DODSpacing.sm)
            }
        }
    }

    // MARK: - Medium

    /// Wide medium-widget layout: hero on the left, copy on the right.
    public struct Medium: View {

        public let content: Content

        public init(content: Content) {
            self.content = content
        }

        public var body: some View {
            HStack(spacing: 0) {
                Hero(url: content.heroImageURL)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: DODSpacing.xs) {
                    Text("Today on DOD")
                        .font(.system(.caption2, design: .default, weight: .semibold))
                        .foregroundStyle(DODColor.burntOrange)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    Text(content.title)
                        .font(.system(.headline, design: .default, weight: .semibold))
                        .foregroundStyle(DODColor.label)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    if !content.excerpt.isEmpty {
                        Text(content.excerpt)
                            .font(.system(.caption, design: .default))
                            .foregroundStyle(DODColor.labelSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    if let totalTime = content.totalTimeDisplay {
                        Spacer(minLength: 0)
                        TimeChip(text: totalTime)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(DODSpacing.md)
                .frame(maxWidth: .infinity)
                .background(DODColor.surfaceElevated)
            }
        }
    }

    // MARK: - Placeholder

    /// AC-9.4: shown when no snapshot exists (first launch, App Group
    /// missing, version mismatch).
    public struct Placeholder: View {

        public init() {}

        public var body: some View {
            VStack(alignment: .leading, spacing: DODSpacing.xs) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(DODColor.burntOrange)
                Text("Dutch Oven Daddy")
                    .font(.system(.headline, design: .default, weight: .semibold))
                    .foregroundStyle(DODColor.label)
                Text("Open the app to see today's featured recipe here.")
                    .font(.system(.caption, design: .default))
                    .foregroundStyle(DODColor.labelSecondary)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(DODSpacing.md)
            .background(DODColor.surfaceElevated)
        }
    }

    // MARK: - Shared primitives

    /// Hero image / fallback gradient. AsyncImage is cheap inside the
    /// widget process; WidgetKit caches its decoded image data.
    struct Hero: View {

        let url: URL?

        var body: some View {
            Group {
                if let url {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .empty, .failure:
                            fallbackGradient
                        @unknown default:
                            fallbackGradient
                        }
                    }
                } else {
                    fallbackGradient
                }
            }
            .clipped()
        }

        private var fallbackGradient: some View {
            LinearGradient(
                colors: [DODColor.burntOrange.opacity(0.85), DODColor.castIronBrown],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                Image(systemName: "fork.knife")
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.7))
            )
        }
    }

    /// Pill chip echoing the in-app RecipeCard look.
    struct TimeChip: View {

        let text: String

        var body: some View {
            HStack(spacing: 4) {
                Image(systemName: "clock")
                Text(text)
            }
            .font(.system(.caption2, design: .default, weight: .semibold))
            .foregroundStyle(DODColor.cream)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(DODColor.castIronBrown.opacity(0.92)))
        }
    }
}

#Preview("Small") {
    WidgetCard.Small(
        content: .init(
            title: "Garlic Butter Skillet Corn",
            excerpt: "An easy 15-minute side dish.",
            heroImageURL: nil,
            totalTimeDisplay: "15 min"
        )
    )
    .frame(width: 158, height: 158)
}

#Preview("Medium") {
    WidgetCard.Medium(
        content: .init(
            title: "Garlic Butter Skillet Corn",
            excerpt: "An easy 15-minute side dish that pairs with everything.",
            heroImageURL: nil,
            totalTimeDisplay: "15 min"
        )
    )
    .frame(width: 338, height: 158)
}

#Preview("Placeholder") {
    WidgetCard.Placeholder()
        .frame(width: 158, height: 158)
}
