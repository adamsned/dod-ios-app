import DODFeatureProfile
import DODPersistence
import DODSupport
import Foundation
import Testing

@testable import DODFeatureFeed

@MainActor
@Suite("SettingsViewModel journal mutation (DUT-694)")
struct SettingsViewModelJournalMutationTests {
    static func isolatedDefaults() -> UserDefaults {
        let suiteName = "SettingsViewModelJournalMutationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test("updateProfileJournalEntry_withNilDependency_returnsTrue")
    func testUpdateProfileJournalEntryWithNilDependency() async {
        let viewModel = SettingsViewModel(defaults: Self.isolatedDefaults(), dependencies: nil)
        let entry = CookLogEntry(
            id: UUID(),
            recipeID: 1001,
            recipeTitle: "Test Recipe",
            cookedAt: .now
        )
        let result = await viewModel.updateProfileJournalEntry(entry)
        #expect(result == true)
    }

    @Test("updateProfileJournalEntry_onSuccess_returnsTrue")
    func testUpdateProfileJournalEntryOnSuccess() async {
        let mockDependency = SuccessfulJournalDependencies()
        let viewModel = SettingsViewModel(
            defaults: Self.isolatedDefaults(),
            dependencies: mockDependency
        )
        let entry = CookLogEntry(
            id: UUID(),
            recipeID: 1001,
            recipeTitle: "Test Recipe",
            cookedAt: .now
        )
        let result = await viewModel.updateProfileJournalEntry(entry)
        #expect(result == true)
        #expect(mockDependency.updateWasCalled == true)
    }

    @Test("updateProfileJournalEntry_onFailure_returnsFalse")
    func testUpdateProfileJournalEntryOnFailure() async {
        let mockDependency = FailingJournalDependencies(error: TestError())
        let viewModel = SettingsViewModel(
            defaults: Self.isolatedDefaults(),
            dependencies: mockDependency
        )
        let entry = CookLogEntry(
            id: UUID(),
            recipeID: 1001,
            recipeTitle: "Test Recipe",
            cookedAt: .now
        )
        let result = await viewModel.updateProfileJournalEntry(entry)
        #expect(result == false)
    }

    @Test("deleteProfileJournalEntry_withNilDependency_returnsTrue")
    func testDeleteProfileJournalEntryWithNilDependency() async {
        let viewModel = SettingsViewModel(defaults: Self.isolatedDefaults(), dependencies: nil)
        let entry = CookLogEntry(
            id: UUID(),
            recipeID: 1001,
            recipeTitle: "Test Recipe",
            cookedAt: .now
        )
        let result = await viewModel.deleteProfileJournalEntry(entry)
        #expect(result == true)
    }

    @Test("deleteProfileJournalEntry_onSuccess_returnsTrue")
    func testDeleteProfileJournalEntryOnSuccess() async {
        let mockDependency = SuccessfulJournalDependencies()
        let viewModel = SettingsViewModel(
            defaults: Self.isolatedDefaults(),
            dependencies: mockDependency
        )
        let entry = CookLogEntry(
            id: UUID(),
            recipeID: 1001,
            recipeTitle: "Test Recipe",
            cookedAt: .now
        )
        let result = await viewModel.deleteProfileJournalEntry(entry)
        #expect(result == true)
        #expect(mockDependency.deleteWasCalled == true)
    }

    @Test("deleteProfileJournalEntry_onFailure_returnsFalse")
    func testDeleteProfileJournalEntryOnFailure() async {
        let mockDependency = FailingJournalDependencies(error: TestError())
        let viewModel = SettingsViewModel(
            defaults: Self.isolatedDefaults(),
            dependencies: mockDependency
        )
        let entry = CookLogEntry(
            id: UUID(),
            recipeID: 1001,
            recipeTitle: "Test Recipe",
            cookedAt: .now
        )
        let result = await viewModel.deleteProfileJournalEntry(entry)
        #expect(result == false)
    }
}

final class SuccessfulJournalDependencies: SettingsDependencies, @unchecked Sendable {
    private(set) var updateWasCalled = false
    private(set) var deleteWasCalled = false

    func cookLogs() async throws -> [CookLogEntry] { [] }
    func setCloudSyncOptIn(_ enabled: Bool) async {}
    func cloudSyncOptInValue() -> Bool { false }

    func updateCookLog(_ entry: CookLogEntry) async throws {
        updateWasCalled = true
    }

    func deleteCookLog(id: UUID) async throws {
        deleteWasCalled = true
    }
}

final class FailingJournalDependencies: SettingsDependencies, @unchecked Sendable {
    private let error: Error

    init(error: Error) {
        self.error = error
    }

    func cookLogs() async throws -> [CookLogEntry] { [] }
    func setCloudSyncOptIn(_ enabled: Bool) async {}
    func cloudSyncOptInValue() -> Bool { false }

    func updateCookLog(_ entry: CookLogEntry) async throws {
        throw error
    }

    func deleteCookLog(id: UUID) async throws {
        throw error
    }
}

struct TestError: Error {}
