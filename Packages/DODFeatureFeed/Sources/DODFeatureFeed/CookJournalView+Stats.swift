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

    /// The three derived header stats (total / weekly streak / most-cooked).
    struct JournalStats: Equatable {
        var total = 0
        var streak = 0
        var mostCooked: CookLogStats.RecipeFrequency?
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
            mostCooked: CookLogStats.mostCooked(cooks)
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
}
