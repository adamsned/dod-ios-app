import DODFeatureProfile
import DODSupport
import Foundation

// DUT-417 / CL-292 — assembles the Settings ▸ Profile view-mode stats from the
// `SettingsDependencies` seam (cook log + saved count + rating count), and
// passes the cook log through for the "View Cooking Journal" sheet. Kept in its
// own (non-UIKit-gated) extension so `SettingsViewModel.swift` stays under the
// SwiftLint 400-line file_length cap and so macOS L1 tests exercise it too.
extension SettingsViewModel {

    /// Whether to surface the profile stats section — true once a real
    /// dependency is wired (the composition root). Previews / unwired hosts
    /// pass nil, so the section stays hidden rather than showing all-zeros.
    public var profileStatsAvailable: Bool { cloudSyncDependency != nil }

    /// Load + compute the current `ProfileStats`. The cook-derived figures use
    /// `CookLogStats` (DODSupport); the view derives the Cook Rank from
    /// `totalCooks`. A failing/absent dependency degrades each figure to zero
    /// rather than throwing.
    public func loadProfileStats() async -> ProfileStats {
        guard let deps = cloudSyncDependency else { return .empty }
        let logs = (try? await deps.cookLogs()) ?? []
        let saved = (try? await deps.savedRecipeCount()) ?? 0
        let reviews = try? await deps.userRatingCount()
        return ProfileStats(
            totalCooks: CookLogStats.totalCooks(logs),
            // DUT-427: use the same pinned calendar the Cooking Journal uses so the
            // streak reads identically in both places (locale-independent) — the
            // default `Calendar.current` follows device locale and diverges.
            weeklyStreak: CookLogStats.currentWeeklyStreak(
                logs,
                asOf: Date(),
                calendar: Self.streakCalendar
            ),
            savedRecipes: saved,
            reviewsWritten: reviews
        )
    }

    /// DUT-427: the pinned Sunday-first Gregorian calendar the weekly-streak buckets
    /// must use everywhere (matches `CookJournalView`), so the number never drifts by
    /// device locale.
    static var streakCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        // DUT-528: pin the timezone explicitly (matches `CookJournalView.weekCalendar`)
        // so week/month buckets never drift under an implicit device-timezone change.
        // `TimeZone.current` keeps today's "a day = the user's local day" semantics
        // while removing the accidental implicit dependency.
        calendar.timeZone = TimeZone.current
        return calendar
    }

    /// Cook log for the journal sheet presented from the profile stats link.
    public func profileJournalEntries() async -> [CookLogEntry] {
        (try? await cloudSyncDependency?.cookLogs()) ?? []
    }

    /// In-place edit of a journal entry from that sheet (note / rating / photo).
    public func updateProfileJournalEntry(_ entry: CookLogEntry) async {
        try? await cloudSyncDependency?.updateCookLog(entry)
    }
}
