import DODDesignSystem
import DODSupport
import SwiftUI

/// DUT-976 — recap for one cookout: pick a cover photo, then share the card.
struct CookoutRecapView: View {
    let group: CookoutGroup
    @State private var thumbnails = CookThumbnailLoader()
    @State private var coverIndex = 0

    /// Cover index clamped into the photo list; 0 when empty.
    static func clampedCoverIndex(_ index: Int, photoCount: Int) -> Int {
        guard photoCount > 0 else { return 0 }
        return min(max(index, 0), photoCount - 1)
    }

    private var coverImage: Image? {
        #if canImport(UIKit)
        let ids = group.photoIDs
        guard !ids.isEmpty,
            let ui = thumbnails.cachedImage(for: ids[Self.clampedCoverIndex(coverIndex, photoCount: ids.count)])
        else { return nil }
        return Image(uiImage: ui)
        #else
        return nil
        #endif
    }

    private var card: CookoutRecapCard {
        CookoutRecapCard(
            headline: group.headline(),
            dishTitles: group.entries.map(\.recipeTitle),
            averageRatingText: CookJournalView.averageRatingTextFormatted(group.averageRating).replacingOccurrences(
                of: "—",
                with: ""
            ).nilIfEmpty,
            cover: coverImage
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DODSpacing.md) {
                card.clipShape(RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous))
                if group.photoIDs.count > 1 {
                    Picker("Cover photo", selection: $coverIndex) {
                        ForEach(group.photoIDs.indices, id: \.self) { Text("Photo \($0 + 1)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                if let url = CookoutRecapRenderer.writeFile(card, day: group.day) {
                    ShareLink(item: url) { Label("Share recap", systemImage: "square.and.arrow.up") }
                        .tint(DODColor.burntOrange)
                }
            }
            .padding(DODSpacing.md)
        }
        .navigationTitle("Cookout Recap")
        .task {
            for id in group.photoIDs { await thumbnails.loadThumbnail(id: id) }
        }
    }
}

extension String {
    fileprivate var nilIfEmpty: String? { isEmpty ? nil : self }
}
