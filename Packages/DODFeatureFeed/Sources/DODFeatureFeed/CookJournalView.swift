import DODDesignSystem
import DODPersistence
import DODSupport
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

/// The "I Made This" cook journal (US-48 / DUT-104) — the user's history of
/// completed cooks with a stats header (total / weekly streak / most-cooked),
/// the retention payoff of the First Cookout path. Reads `[CookLogEntry]` via an
/// injected async loader (so previews/tests stay zero-config); photos resolve
/// through ``CookPhotoStore`` by `photoLocalID`.
public struct CookJournalView: View {

    private let load: () async -> [CookLogEntry]
    private let photoStore = CookPhotoStore()
    @State private var cooks: [CookLogEntry] = []
    @State private var loaded = false
    @Environment(\.dismiss) private var dismiss

    public init(load: @escaping () async -> [CookLogEntry]) {
        self.load = load
    }

    public var body: some View {
        NavigationStack {
            Group {
                if cooks.isEmpty {
                    emptyState
                } else {
                    journalList
                }
            }
            .background(DODColor.surface)
            .navigationTitle("Cook Journal")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(DODColor.burntOrange)
                }
            }
        }
        .task {
            if !loaded {
                cooks = await load()
                loaded = true
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: DODSpacing.md) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundStyle(DODColor.burntOrange)
            Text("No cooks logged yet")
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.label)
            Text("Finish Your First Cookout and it shows up here — every cook builds your streak.")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DODSpacing.xl)
    }

    private var journalList: some View {
        ScrollView {
            VStack(spacing: DODSpacing.md) {
                statsHeader
                ForEach(cooks) { cook in
                    cookRow(cook)
                }
            }
            .padding(DODSpacing.md)
        }
    }

    private var statsHeader: some View {
        let total = CookLogStats.totalCooks(cooks)
        let streak = CookLogStats.currentWeeklyStreak(cooks, asOf: .now, calendar: .current)
        let mostCooked = CookLogStats.mostCooked(cooks)
        return HStack(spacing: DODSpacing.sm) {
            statTile("\(total)", total == 1 ? "cook" : "cooks")
            statTile("\(streak)", "week streak")
            if let mostCooked {
                statTile("\(mostCooked.count)×", "top: \(mostCooked.title)")
            }
        }
    }

    private func statTile(_ value: String, _ label: String) -> some View {
        VStack(spacing: DODSpacing.xxs) {
            Text(value)
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.burntOrange)
            Text(label)
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(DODSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DODSpacing.sm, style: .continuous)
                .fill(DODColor.surfaceElevated)
        )
    }

    private func cookRow(_ cook: CookLogEntry) -> some View {
        HStack(spacing: DODSpacing.md) {
            photoThumbnail(cook.photoLocalID)
            VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                Text(cook.recipeTitle)
                    .dodFont(DODType.bodyEmphasized)
                    .foregroundStyle(DODColor.label)
                Text(cook.cookedAt.formatted(date: .abbreviated, time: .omitted))
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(DODSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DODSpacing.sm, style: .continuous)
                .fill(DODColor.surfaceElevated)
        )
    }

    @ViewBuilder private func photoThumbnail(_ id: String?) -> some View {
        if let id, let data = photoStore.data(forID: id), let image = imageFromData(data) {
            image
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: DODSpacing.xs, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: DODSpacing.xs, style: .continuous)
                .fill(DODColor.burntOrange.opacity(0.15))
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "flame.fill")
                        .foregroundStyle(DODColor.burntOrange)
                )
        }
    }

    private func imageFromData(_ data: Data) -> Image? {
        #if canImport(UIKit)
            if let uiImage = UIImage(data: data) { return Image(uiImage: uiImage) }
        #endif
        return nil
    }
}
