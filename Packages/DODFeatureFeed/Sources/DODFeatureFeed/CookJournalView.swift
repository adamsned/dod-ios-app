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
    /// CL-273 — persist an entry's edited reflection / photo. DUT-694 (PR-D) —
    /// returns whether the write succeeded so a failure surfaces instead of being
    /// swallowed. Defaults to a success no-op so previews / tests that only pass
    /// `load` keep compiling.
    private let update: (CookLogEntry) async -> Bool
    /// DUT-514 — delete an entry (cascades its photo in the store). DUT-694 (PR-D) —
    /// returns whether the delete succeeded so a failure surfaces instead of the
    /// "deleted" entry silently reappearing on reload. Defaults to a success no-op
    /// so previews / tests that only pass `load` keep compiling.
    private let delete: (CookLogEntry) async -> Bool
    /// DUT-588 — off-main, downsampled, id-cached thumbnail loader. Replaces the
    /// old synchronous full-res `photoStore.data(forID:)` + `UIImage(data:)`
    /// decode that ran per row in the view body.
    @State private var thumbnails = CookThumbnailLoader()
    @State private var cooks: [CookLogEntry] = []
    @State private var loaded = false
    /// DUT-514 — the entry the user is confirming a delete for (drives the alert).
    @State private var pendingDelete: CookLogEntry?
    /// DUT-694 (PR-D) — a failed delete/edit surfaces here (was swallowed by a
    /// `try?` in the view-model). Drives a failure alert mirroring the DUT-340
    /// photo-save alert in ``CookJournalEntryView``, so the user learns why the
    /// entry is still there rather than seeing it silently reappear after
    /// confirming a can't-be-undone delete.
    @State private var actionError: JournalActionError?
    @Environment(\.dismiss) private var dismiss

    /// DUT-694 (PR-D) — a titled failure message for the delete/edit error alert.
    struct JournalActionError: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    /// DUT-272 — the three mutually exclusive states the body renders. Split out
    /// as a pure function so the load-order gating is unit-testable without a live
    /// SwiftUI hierarchy: the empty state is only reachable once a load has
    /// genuinely resolved (`loaded == true`) AND returned nothing.
    enum ContentState: Equatable {
        case loading
        case empty
        case list
    }

    static func contentState(loaded: Bool, isEmpty: Bool) -> ContentState {
        guard loaded else { return .loading }
        return isEmpty ? .empty : .list
    }

    /// DUT-232 — VoiceOver label for a journal photo thumbnail. Static so it's
    /// assertable in tests without rendering the view.
    static let photoThumbnailAccessibilityLabel = "Photo of this cook"

    public init(
        load: @escaping () async -> [CookLogEntry],
        update: @escaping (CookLogEntry) async -> Bool = { _ in true },
        delete: @escaping (CookLogEntry) async -> Bool = { _ in true }
    ) {
        self.load = load
        self.update = update
        self.delete = delete
    }

    public var body: some View {
        NavigationStack {
            Group {
                // DUT-272 — `cooks` starts `[]` and is filled asynchronously by
                // the `.task` loader, so gating the empty state on `cooks.isEmpty`
                // alone flashed "No Cooks Logged Yet" on open for users who DO have
                // cooks. Gate on `loaded` too (see `contentState`): show a spinner
                // until a load has genuinely returned, so the empty state only
                // appears once we know the journal is really empty.
                switch Self.contentState(loaded: loaded, isEmpty: cooks.isEmpty) {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .empty:
                    emptyState
                case .list:
                    journalList
                }
            }
            .background(DODColor.surface)
            .navigationTitle("Cooking Journal")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(DODColor.burntOrange)
                }
            }
            // DUT-514 — confirm before deleting: a cook counts toward rank, so a
            // stray swipe/menu tap shouldn't wipe a memory silently.
            .alert(
                "Delete This Cook?",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                presenting: pendingDelete
            ) { entry in
                Button("Delete", role: .destructive) {
                    Task { await performDelete(entry) }
                }
                Button("Cancel", role: .cancel) {}
            } message: { entry in
                Text("This removes \"\(entry.recipeTitle)\" and its photo from your journal. This can't be undone.")
            }
            // DUT-694 (PR-D) — surface a swallowed delete/edit failure (mirrors the
            // DUT-340 photo-save alert in CookJournalEntryView) so the reload's
            // reappearing entry has an explanation instead of reading as a bug.
            .alert(
                actionError?.title ?? "",
                isPresented: Binding(
                    get: { actionError != nil },
                    set: { if !$0 { actionError = nil } }
                ),
                presenting: actionError
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { error in
                Text(error.message)
            }
        }
        .task {
            if !loaded {
                cooks = await load()
                loaded = true
            }
        }
    }

    /// DUT-514 — run the delete, then reload so the list AND the stats header
    /// (total / streak / most-cooked, all derived from `cooks`) recompute.
    private func performDelete(_ entry: CookLogEntry) async {
        pendingDelete = nil
        let didDelete = await delete(entry)
        cooks = await load()
        // DUT-694 (PR-D) — on failure the reload brings the entry back; without
        // this the user sees it silently reappear after confirming a "can't be
        // undone" delete. Surface why so it doesn't read as a bug.
        if !didDelete {
            actionError = JournalActionError(
                title: "Couldn't Delete Cook",
                message: "We couldn't delete this cook. Please try again."
            )
        }
    }
}

// DUT-694 (PR-D) — the rendering helpers live in a same-file extension so the
// primary `CookJournalView` declaration stays under SwiftLint's `type_body_length`
// cap after the delete/edit failure-surfacing additions landed. Same file, so the
// `private` state (`cooks`, `thumbnails`) stays reachable.
extension CookJournalView {

    private var emptyState: some View {
        VStack(spacing: DODSpacing.md) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundStyle(DODColor.burntOrange)
                .accessibilityHidden(true)
            Text("No Cooks Logged Yet")
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
            // DUT-588 — LazyVStack so off-screen rows aren't built (and their
            // thumbnails aren't loaded/decoded) until they scroll into view; the
            // old eager `VStack` built every row on open.
            LazyVStack(spacing: DODSpacing.md) {
                journeyHeader
                statsHeader
                ForEach(cooks) { cook in
                    // CL-273 — tap an entry to open its personal page (write a
                    // reflection, add a photo). Reload after a save so the row
                    // reflects the new note / photo.
                    NavigationLink {
                        CookJournalEntryView(entry: cook) { updated in
                            let didUpdate = await update(updated)
                            cooks = await load()
                            // DUT-694 (PR-D) — the entry page already dismissed, so
                            // surface a swallowed edit failure here rather than
                            // silently losing the reflection / photo change.
                            if !didUpdate {
                                actionError = JournalActionError(
                                    title: "Couldn't Save Changes",
                                    message: "We couldn't save your changes. Please try again."
                                )
                            }
                        } onDelete: {
                            // DUT-514 — Delete from inside the open entry page.
                            // No extra confirm: the entry view already confirms.
                            await performDelete(cook)
                        }
                    } label: {
                        cookRow(cook)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("journal-row-\(cook.id.uuidString)")
                    // DUT-514 — the journal is a ScrollView (not a List), so
                    // `.swipeActions` isn't available here; a long-press context
                    // menu + a VoiceOver action give an equivalent delete
                    // affordance. Both route through the same confirm alert.
                    .contextMenu {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            pendingDelete = cook
                        }
                    }
                    .accessibilityAction(named: "Delete") { pendingDelete = cook }
                }
            }
            .padding(DODSpacing.md)
        }
    }

    /// Transformation header (North Star): the cook's identity rank + the next
    /// rung pulling them forward, so the journal opens with how far they've come,
    /// not just a count. Only rendered with >= 1 cook (journalList is gated on a
    /// non-empty list), so `currentRank` is non-nil — the fallbacks are defensive.
    private var journeyHeader: some View {
        // DUT-685 — the RANK must count the SAME path-only population the rank-up
        // celebration counts (journal minus off-path dump cakes), not the raw
        // `totalCooks`. Both now go through `CookLogStats.rankLadderCookCount`, so
        // the visible rank and the next celebration can never contradict. The
        // "total cooks" stat tile in `statsHeader` still uses `totalCooks`.
        let rankCooks = CookLogStats.rankLadderCookCount(cooks)
        let current = CookProgression.currentRank(totalCooks: rankCooks)
        let next = CookProgression.nextRank(totalCooks: rankCooks)
        let toNext = CookProgression.cooksToNextRank(totalCooks: rankCooks)
        let progress = CookProgression.progressToNextRank(totalCooks: rankCooks)
        return VStack(spacing: DODSpacing.xs) {
            Text(current?.emoji ?? "🔥")
                .font(.system(size: 44))
                .accessibilityHidden(true)
            Text("You're a \(current?.title ?? "Fire Starter")")
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.label)
                .multilineTextAlignment(.center)
            if let next, let toNext {
                ProgressView(value: progress)
                    .tint(DODColor.burntOrange)
                    .padding(.horizontal, DODSpacing.md)
                Text("\(toNext) more cook\(toNext == 1 ? "" : "s") to \(next.emoji) \(next.title)")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Top of the path. You're a certified Dutch Oven Daddy. 👑")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.burntOrange)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DODSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                .fill(DODColor.surfaceElevated)
        )
        .accessibilityElement(children: .combine)
    }

    private var statsHeader: some View {
        let total = CookLogStats.totalCooks(cooks)
        // DUT-346: a fixed-firstWeekday Gregorian calendar so a locale's week-start
        // (Sun vs Mon) can't bucket the same cook history into a different streak
        // across devices.
        // DUT-528: pin the timezone explicitly (matches `SettingsViewModel.streakCalendar`)
        // so week/month buckets never drift under an implicit device-timezone change.
        var weekCalendar = Calendar(identifier: .gregorian)
        weekCalendar.firstWeekday = 1
        weekCalendar.timeZone = TimeZone.current
        let streak = CookLogStats.currentWeeklyStreak(cooks, asOf: .now, calendar: weekCalendar)
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
            RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
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
                // CL-273 — a glimpse of the reflection, so the journal reads as
                // memories, not just a log. Tap the row for the full entry.
                if let note = cook.note, !note.isEmpty {
                    Text(note)
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.label)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(DODColor.labelSecondary)
        }
        .padding(DODSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                .fill(DODColor.surfaceElevated)
        )
    }

    /// DUT-588 — the thumbnail loads asynchronously (off the main thread, id
    /// cached, downsampled to 56pt) via ``CookThumbnailLoader``. Until a decoded
    /// image lands — and permanently for a missing / undecodable file — the row
    /// shows the same flame placeholder as before, so nothing crashes on a
    /// deleted photo and the layout never shifts.
    @ViewBuilder private func photoThumbnail(_ id: String?) -> some View {
        Group {
            if let id, let image = decodedThumbnail(for: id) {
                image
                    .resizable()
                    .scaledToFill()
                    // DUT-232 — VoiceOver otherwise announces a generic "image".
                    .accessibilityLabel(Text(Self.photoThumbnailAccessibilityLabel))
            } else {
                RoundedRectangle(cornerRadius: DODRadius.inner, style: .continuous)
                    .fill(DODColor.burntOrange.opacity(0.15))
                    .overlay(
                        Image(systemName: "flame.fill")
                            .foregroundStyle(DODColor.burntOrange)
                    )
                    // DUT-232 — the flame is a decorative placeholder for a
                    // missing photo; hide it so VoiceOver doesn't stop on a
                    // meaningless glyph.
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: DODRadius.inner, style: .continuous))
        .task(id: id) {
            if let id { await thumbnails.loadThumbnail(id: id) }
        }
    }

    /// The cached, downsampled thumbnail for `id`, or nil if not yet decoded.
    private func decodedThumbnail(for id: String) -> Image? {
        #if canImport(UIKit)
        if let uiImage = thumbnails.cachedImage(for: id) { return Image(uiImage: uiImage) }
        #endif
        return nil
    }
}
