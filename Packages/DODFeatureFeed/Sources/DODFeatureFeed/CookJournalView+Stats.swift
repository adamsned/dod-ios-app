import DODDesignSystem
import DODSupport
import Foundation
import SwiftUI

// DUT — the cook-journal header stats, derived ONCE whenever `cooks` changes
// (via `.onChange(of:)`) rather than recomputed on every `body` eval inside the
// `statsHeader` computed `View` property. Kept in its own file so the primary
// `CookJournalView` declaration stays under SwiftLint's `file_length` cap. The
// type + derivation are pure (no private instance state), so they live cleanly
// in a separate file; the `stats` @State and `statsHeader` view stay in the
// main file where they can reach `CookJournalView`'s private state.
extension CookJournalView {

    /// The derived header stats (total / weekly streak / most-cooked), plus the
    /// DUT-882 iOS-parity additions (average rating / cooks in the last 30 days)
    /// that back the summary card below the header.
    struct JournalStats: Equatable {
        var total = 0
        var streak = 0
        var mostCooked: CookLogStats.RecipeFrequency?
        /// DUT-882 — nil when nothing has been rated yet (shows a placeholder
        /// rather than a misleading "0.0").
        var averageRating: Double?
        /// DUT-882 — cooks logged in the trailing 30-calendar-day window.
        var last30Days = 0
    }

    /// Derive the header stats from a cook history. Pure + static so the
    /// (unchanged) numbers stay unit-testable without a live view.
    static func computeStats(_ cooks: [CookLogEntry]) -> JournalStats {
        // DUT-346: a fixed-firstWeekday Gregorian calendar so a locale's week-start
        // (Sun vs Mon) can't bucket the same cook history into a different streak
        // across devices. DUT-528: pin the timezone explicitly (matches
        // `SettingsViewModel.streakCalendar`) so week/month buckets never drift
        // under an implicit device-timezone change.
        var weekCalendar = Calendar(identifier: .gregorian)
        weekCalendar.firstWeekday = 1
        weekCalendar.timeZone = TimeZone.current
        return JournalStats(
            total: CookLogStats.totalCooks(cooks),
            streak: CookLogStats.currentWeeklyStreak(cooks, asOf: .now, calendar: weekCalendar),
            mostCooked: CookLogStats.mostCooked(cooks),
            averageRating: CookLogStats.averageRating(cooks),
            last30Days: CookLogStats.cooksInLast30Days(cooks, asOf: .now, calendar: weekCalendar)
        )
    }

    /// A single header stat tile (value over label). Lives here (not the main
    /// file) purely for `file_length` relief — it holds no instance state, so
    /// `statsHeader` in the main file calls it across the extension boundary.
    func statTile(_ value: String, _ label: String) -> some View {
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
        // DUT — merge the value + label so VoiceOver reads "5 cooks" as one element,
        // not a contextless "5" then "cooks" (mirrors `journeyHeader`).
        .accessibilityElement(children: .combine)
    }

    /// DUT-882 — the iOS-parity stats summary card (Android's Cook Journal
    /// stats: total cooks, average rating, most-cooked recipe, cooks in the
    /// last 30 days), laid out as a 2×2 grid of ``statTile``s below the
    /// existing habit-streak header. Takes plain values (not private state) so
    /// it can live in this file alongside `statTile`, mirroring the existing
    /// split between pure rendering helpers here and stateful views in the
    /// main `CookJournalView` file.
    func statsSummaryCard(stats: JournalStats) -> some View {
        VStack(spacing: DODSpacing.sm) {
            HStack(spacing: DODSpacing.sm) {
                statTile("\(stats.total)", stats.total == 1 ? "total cook" : "total cooks")
                statTile(Self.averageRatingText(stats.averageRating), "avg rating")
            }
            HStack(spacing: DODSpacing.sm) {
                statTile(stats.mostCooked?.title ?? "—", "most cooked")
                statTile("\(stats.last30Days)", "cooks (30d)")
            }
        }
    }

    /// "4.3"-style formatting for the average-rating tile, or an em dash when
    /// nothing has been rated yet (DUT-882 — no ratings shouldn't read as "0.0").
    private static func averageRatingText(_ average: Double?) -> String {
        guard let average else { return "—" }
        return String(format: "%.1f", average)
    }
}
