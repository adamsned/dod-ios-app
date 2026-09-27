import DODSupport
import Foundation
import Testing

@testable import DODFeatureFeed

/// DUT-160 — the Privacy Dashboard groups the user's data by location into three
/// buckets, each row carrying a live count/location + a plain-language
/// explanation. These pin the pure bucket-assembly logic and the view-model's
/// count load off the `SettingsDependencies` seam (guest-safe).
@MainActor
@Suite("Privacy Dashboard (DUT-160)")
struct PrivacyDashboardViewModelTests {

    // MARK: - Bucket assembly (pure)

    @Test func buildsThreeBucketsInOrder() {
        let buckets = PrivacyBucket.buckets(for: PrivacyInventory())
        #expect(buckets.map(\.id) == [.onDevice, .iCloud, .publicBlog])
        #expect(buckets[0].title == "On Device")
        #expect(buckets[1].title == "iCloud (Private)")
        #expect(buckets[2].title == "Public (Blog)")
    }

    @Test func onDeviceBucketShowsLiveCountsForEveryCategory() {
        let inventory = PrivacyInventory(
            savedRecipes: 3,
            journalEntries: 1,
            shoppingListItems: 12,
            hasProfile: true
        )
        let onDevice = PrivacyBucket.onDevice(inventory)
        let byID = Dictionary(uniqueKeysWithValues: onDevice.rows.map { ($0.id, $0) })

        #expect(byID["onDevice.saved"]?.detail == "3 recipes")
        // Singular pluralization.
        #expect(byID["onDevice.journal"]?.detail == "1 entry")
        #expect(byID["onDevice.shopping"]?.detail == "12 items")
        #expect(byID["onDevice.profile"]?.detail == "Set up")
    }

    @Test func profileRowReflectsGuestState() {
        let onDevice = PrivacyBucket.onDevice(PrivacyInventory(hasProfile: false))
        let profile = onDevice.rows.first { $0.id == "onDevice.profile" }
        #expect(profile?.detail == "Not set up")
    }

    @Test func iCloudBucketReflectsSyncOn() {
        let bucket = PrivacyBucket.iCloud(PrivacyInventory(savedRecipes: 5, iCloudSyncOn: true))
        #expect(bucket.rows.count == 1)
        let row = bucket.rows.first
        #expect(row?.id == "iCloud.saved")
        #expect(row?.detail == "Syncing")
        // Only saved recipes sync; the explanation says the rest stay local.
        #expect(row?.explanation.contains("stay on this device") == true)
    }

    @Test func iCloudBucketReflectsSyncOff() {
        let bucket = PrivacyBucket.iCloud(PrivacyInventory(iCloudSyncOn: false))
        let row = bucket.rows.first
        #expect(row?.id == "iCloud.off")
        #expect(row?.detail == "Off")
    }

    /// AC — the Public bucket explicitly states comments/ratings are visible on
    /// the blog and carry the user's name and email.
    @Test func publicBucketStatesNameAndEmailAreVisible() {
        let bucket = PrivacyBucket.publicBlog(PrivacyInventory(ratingsPosted: 2))
        #expect(bucket.summary.contains("dutchovendaddy.com"))
        #expect(bucket.summary.lowercased().contains("name and email"))
        for row in bucket.rows {
            #expect(row.explanation.contains("dutchovendaddy.com"))
            #expect(row.explanation.lowercased().contains("name and email"))
        }
        let ratings = bucket.rows.first { $0.id == "public.ratings" }
        #expect(ratings?.detail == "2 posted")
    }

    // MARK: - Live count load (guest-safe)

    @Test func loadPullsCountsFromDependency() async {
        let logs = (0..<4).map {
            CookLogEntry(id: UUID(), recipeID: $0, recipeTitle: "Cook", cookedAt: .now)
        }
        let deps = FakePrivacyDependencies(saved: 7, ratings: 3, shopping: 5, logs: logs)
        let viewModel = PrivacyDashboardViewModel()

        await viewModel.load(from: deps, hasProfile: true, iCloudSyncOn: true)

        let inventory = viewModel.inventory
        #expect(inventory?.savedRecipes == 7)
        #expect(inventory?.journalEntries == 4)
        #expect(inventory?.shoppingListItems == 5)
        #expect(inventory?.ratingsPosted == 3)
        #expect(inventory?.hasProfile == true)
        #expect(inventory?.iCloudSyncOn == true)
        #expect(viewModel.buckets.count == 3)
    }

    @Test func loadWithoutDependencyStillHonorsFlags() async {
        let viewModel = PrivacyDashboardViewModel()
        await viewModel.load(from: nil, hasProfile: false, iCloudSyncOn: false)

        let inventory = viewModel.inventory
        #expect(inventory?.savedRecipes == 0)
        #expect(inventory?.shoppingListItems == 0)
        #expect(inventory?.hasProfile == false)
        // A nil dependency degrades to an all-zero, guest inventory rather than
        // no buckets — the dashboard still renders for signed-out users.
        #expect(viewModel.buckets.count == 3)
    }
}

/// L1 double that returns fixed on-device counts for the Privacy Dashboard load.
/// The cloud-sync members are inert (only the count path is exercised).
final class FakePrivacyDependencies: SettingsDependencies, @unchecked Sendable {
    private let saved: Int
    private let ratings: Int
    private let shopping: Int
    private let logs: [CookLogEntry]

    init(saved: Int, ratings: Int, shopping: Int, logs: [CookLogEntry]) {
        self.saved = saved
        self.ratings = ratings
        self.shopping = shopping
        self.logs = logs
    }

    func setCloudSyncOptIn(_ enabled: Bool) async {}
    func cloudSyncOptInValue() -> Bool { false }
    func cookLogs() async throws -> [CookLogEntry] { logs }
    func savedRecipeCount() async throws -> Int { saved }
    func userRatingCount() async throws -> Int { ratings }
    func shoppingListItemCount() async throws -> Int { shopping }
}
