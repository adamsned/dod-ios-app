import DODSupport
import Foundation

/// Cooking Journal reads/writes for ``FeedViewModel`` (DUT-104 / CL-273 /
/// DUT-514) plus the DUT-625 rank-ladder population helper, extracted here so
/// the main view-model file stays under the SwiftLint `file_length` cap.
/// Members stay `public` / `internal` so the journal views and `logCook` in the
/// main file reach them across the extension boundary.
extension FeedViewModel {

    /// DUT-104 — the logged cooks (newest first) for the Cooking Journal view.
    public func cookLogs() async -> [CookLogEntry] {
        (try? await dependencies.cookLogs()) ?? []
    }

    /// CL-273 — save a journal entry's personal reflection / photo. Best-effort
    /// (a journal write never blocks the UI). This updates an existing entry in
    /// place and never logs a new cook, so it cannot change the cook count and
    /// therefore cannot affect rank.
    public func updateCook(_ entry: CookLogEntry) async {
        try? await dependencies.updateCookLog(entry)
    }

    /// DUT-514 — delete a journal entry (cascades its photo file in the store).
    /// Best-effort, mirroring `updateCook`. Unlike an edit this DOES change the
    /// cook count, so the journal must reload its stats after — the view does that
    /// by re-running its `load` closure once this returns.
    public func deleteCook(_ entry: CookLogEntry) async {
        try? await dependencies.deleteCookLog(id: entry.id)
    }

    /// DUT-625 / DUT-685 — the cook count that feeds the RANK ladder (journal
    /// minus off-path dump-cake cooks). Forwards to ``CookLogStats/rankLadderCookCount(_:)``
    /// (DODSupport), the single source of truth shared by the rank-up CELEBRATION
    /// here and the rank DISPLAY (Cooking Journal + Settings profile), so the two
    /// can never diverge again. `nonisolated` so it stays callable off the main
    /// actor from `logCook`'s background log fetches.
    nonisolated static func rankLadderCookCount(_ logs: [CookLogEntry]) -> Int {
        CookLogStats.rankLadderCookCount(logs)
    }
}
