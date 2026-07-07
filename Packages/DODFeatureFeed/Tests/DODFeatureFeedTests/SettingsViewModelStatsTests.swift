import DODFeatureProfile
import DODPersistence
import DODSupport
import Foundation
import Testing

@testable import DODFeatureFeed

/// DUT-685 — the Settings ▸ Profile stats surface must derive the Cook Rank from
/// the path-only `rankLadderCooks` (total minus off-path dump cakes), the SAME
/// population the rank-up celebration counts, so the visible rank and the next
/// celebration never contradict. `totalCooks` stays the true "Total Cooks" stat.
@MainActor
@Suite("SettingsViewModel profile stats (DUT-685)")
struct SettingsViewModelStatsTests {

    /// A journal of N path cooks + M dump cakes yields `rankLadderCooks == N` and
    /// `totalCooks == N + M`, and the displayed rank matches the celebration's
    /// path-only population (never the higher rung the raw total would show).
    @Test func profileStatsRankUsesPathOnlyCount() async throws {
        let dumpCakeID = DumpCake.all[0].id
        let logs = [
            CookLogEntry(id: UUID(), recipeID: 1001, recipeTitle: "Path", cookedAt: .now),
            CookLogEntry(id: UUID(), recipeID: 1002, recipeTitle: "Path", cookedAt: .now),
            CookLogEntry(id: UUID(), recipeID: dumpCakeID, recipeTitle: "Dump", cookedAt: .now),
            CookLogEntry(id: UUID(), recipeID: dumpCakeID, recipeTitle: "Dump", cookedAt: .now),
            CookLogEntry(id: UUID(), recipeID: dumpCakeID, recipeTitle: "Dump", cookedAt: .now),
        ]
        let deps = StatsSettingsDependencies(logs: logs)
        let viewModel = SettingsViewModel(defaults: Self.isolatedDefaults(), dependencies: deps)

        let stats = await viewModel.loadProfileStats()

        // Total counts ALL cooks; the rank population excludes the 3 dump cakes.
        #expect(stats.totalCooks == 5)
        #expect(stats.rankLadderCooks == 2)
        // The DISPLAYED rank derives from the path-only count and matches what the
        // celebration would count — Fire Starter (thr 1), not the Lid Lifter (thr
        // 5) the raw total would (wrongly) show.
        let displayRank = CookProgression.currentRank(totalCooks: stats.rankLadderCooks)
        #expect(displayRank?.title == "Fire Starter")
        #expect(CookProgression.currentRank(totalCooks: stats.totalCooks)?.title == "Lid Lifter")
    }

    static func isolatedDefaults() -> UserDefaults {
        let suiteName = "SettingsViewModelStatsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

/// L1 double that returns a fixed cook log so `loadProfileStats` can be asserted;
/// the cloud-sync flag members are inert (only the stats path is exercised).
final class StatsSettingsDependencies: SettingsDependencies, @unchecked Sendable {
    private let logs: [CookLogEntry]

    init(logs: [CookLogEntry]) {
        self.logs = logs
    }

    func cookLogs() async throws -> [CookLogEntry] { logs }
    func setCloudSyncOptIn(_ enabled: Bool) async {}
    func cloudSyncOptInValue() -> Bool { false }
}
