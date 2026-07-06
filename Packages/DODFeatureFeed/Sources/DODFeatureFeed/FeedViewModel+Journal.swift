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

    /// DUT-625 — the cook count that feeds the RANK ladder: the journal minus
    /// off-path dump-cake cooks. Product assumption: dump cakes are "Anytime
    /// Treats" off the guided path, and graduation is path-only, so a first-ever
    /// dump cake must NOT fire a rank-up the path population wouldn't earn. This
    /// keeps the rank branch and the graduation check counting the same set.
    /// `nonisolated` (with the dump-cake id set built locally from the static,
    /// Sendable `DumpCake.all`) so it's callable off the main actor.
    nonisolated static func rankLadderCookCount(_ logs: [CookLogEntry]) -> Int {
        let dumpCakeRecipeIDs = Set(DumpCake.all.map(\.id))
        return logs.filter { !dumpCakeRecipeIDs.contains($0.recipeID) }.count
    }
}
