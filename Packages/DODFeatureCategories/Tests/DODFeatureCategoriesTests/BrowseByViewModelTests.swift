import DODDomain
import Foundation
import Testing

@testable import DODFeatureCategories

struct BrowseTestError: Error {}

struct FakeAxesProvider: BrowseAxesProviding {
    let result: Result<BrowseAxesConfig, any Error>

    func loadAxes() async throws -> BrowseAxesConfig {
        try result.get()
    }
}
