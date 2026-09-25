// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DODFeatureSaved",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DODFeatureSaved", targets: ["DODFeatureSaved"])
    ],
    dependencies: [
        .package(path: "../DODDomain"),
        .package(path: "../DODSupport"),
        .package(path: "../DODDesignSystem"),
        .package(path: "../DODAnalytics"),
        .package(path: "../DODNetworking"),
        .package(path: "../DODPersistence"),
        // v2 on-device AI — the PROTOCOL seam only (no FoundationModels import
        // here; the Live impl lives in the leaf package and is App-injected).
        .package(path: "../DODIntelligence"),
        // Test-only — top-level screen visual regression (US-18 / T-332).
        // Pin matches `DODDesignSystem/Package.swift` so the package graph
        // resolves a single `swift-snapshot-testing` version.
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0"),
    ],
    targets: [
        .target(
            name: "DODFeatureSaved",
            dependencies: [
                "DODDomain",
                "DODSupport",
                "DODDesignSystem",
                "DODAnalytics",
                "DODNetworking",
                "DODPersistence",
                "DODIntelligence",
            ]
        ),
        .testTarget(
            name: "DODFeatureSavedTests",
            dependencies: [
                "DODFeatureSaved",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            resources: [.process("__Snapshots__")]
        ),
    ]
)
