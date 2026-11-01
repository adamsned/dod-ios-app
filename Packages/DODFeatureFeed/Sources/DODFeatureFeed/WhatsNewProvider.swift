import DODNetworking
import Foundation

/// DUT-174 — loads release notes from WP REST, falling back to a bundled list offline.
public struct WhatsNewProvider: Sendable {
    public typealias Fetch = @Sendable () async throws -> [ChangelogRelease]
    private let fetch: Fetch

    public init(fetch: @escaping Fetch) { self.fetch = fetch }

    public static func live(client: WPChangelogClient = WPChangelogClient()) -> WhatsNewProvider {
        WhatsNewProvider(fetch: { try await client.releases() })
    }

    /// Compiled-in notes so the sheet renders with no network. Add an entry per shipped release.
    public static let bundledFallback: [ChangelogRelease] = [
        ChangelogRelease(
            version: "2.0",
            title: "Welcome to the new Dutch Oven Daddy",
            bullets: ["A fresh Seasoned Cast Iron look", "Faster recipe loading", "Bug fixes and polish"]
        )
    ]

    /// Newest-first. Network result wins when non-empty; any failure or an empty list uses the fallback.
    public func releases() async -> [ChangelogRelease] {
        let fetched = (try? await fetch()) ?? []
        let source = fetched.isEmpty ? Self.bundledFallback : fetched
        return source.sorted { Self.isNewer($0.version, than: $1.version) }
    }

    /// The release matching `version`, else the newest one.
    public func release(for version: String) async -> ChangelogRelease? {
        let all = await releases()
        return all.first { $0.version == version } ?? all.first
    }

    /// Numeric dotted-version compare ("2.10" > "2.9"). Missing components count as 0.
    nonisolated static func isNewer(_ lhs: String, than rhs: String) -> Bool {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(left.count, right.count) {
            let leftValue = index < left.count ? left[index] : 0
            let rightValue = index < right.count ? right[index] : 0
            if leftValue != rightValue { return leftValue > rightValue }
        }
        return false
    }
}
