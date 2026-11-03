import DODDomain
import Foundation
import Observation

public protocol BrowseAxesProviding: Sendable {
    func loadAxes() async throws -> BrowseAxesConfig
}
