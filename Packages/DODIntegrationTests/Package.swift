// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DODIntegrationTests",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DODIntegrationTests", targets: ["DODIntegrationTests"])
    ],
    dependencies: [
        .package(path: "../DODDomain"),
        .package(path: "../DODNetworking"),
        // REG-16 / T-420: the live newest-post test caches the fetched list
        // through `RecipeStore.cache(listItems:)` and reads it back via
        // `RecipeStore.listItems(forIDs:)`, exercising the exact same
        // production feed-load path `LiveFeedDependencies.cache(listItems:)`
        // uses. Only the new test method needs SwiftData wiring; the other
        // five `LiveAPITests` methods don't depend on these.
        .package(path: "../DODPersistence"),
    ],
    targets: [
        // Empty source target so the package is valid; everything lives in Tests/.
        .target(name: "DODIntegrationTests"),
        .testTarget(
            name: "DODIntegrationTestsTests",
            dependencies: [
                "DODIntegrationTests",
                "DODDomain",
                "DODNetworking",
                "DODPersistence",
            ]
        ),
    ]
)
