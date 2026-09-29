// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DODFeatureFeed",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DODFeatureFeed", targets: ["DODFeatureFeed"])
    ],
    dependencies: [
        .package(path: "../DODDomain"),
        .package(path: "../DODSupport"),
        .package(path: "../DODDesignSystem"),
        .package(path: "../DODAnalytics"),
        .package(path: "../DODNetworking"),
        .package(path: "../DODPersistence"),
        // T-934 (US-54) — the Cooking Tools AI helper depends only on the
        // DODIntelligence PROTOCOL seam (never FoundationModels), mirroring how
        // DODFeatureSaved consumes it for the substitution surface.
        .package(path: "../DODIntelligence"),
        // US-44 (T-739) — Profile section + edit view at the top of
        // Settings. `DODFeatureFeed` owns `SettingsView` so it consumes
        // the Profile UI surface directly.
        .package(path: "../DODFeatureProfile"),
        // Test-only — top-level screen visual regression (US-18 / T-332).
        // Pin matches `DODDesignSystem/Package.swift` so the package graph
        // resolves a single `swift-snapshot-testing` version.
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0"),
    ],
    targets: [
        .target(
            name: "DODFeatureFeed",
            dependencies: [
                "DODDomain",
                "DODSupport",
                "DODDesignSystem",
                "DODAnalytics",
                "DODNetworking",
                "DODPersistence",
                "DODIntelligence",
                "DODFeatureProfile",
            ]
        ),
        .testTarget(
            name: "DODFeatureFeedTests",
            dependencies: [
                "DODFeatureFeed",
                "DODSupport",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            resources: [.process("__Snapshots__")]
        ),
    ]
)
