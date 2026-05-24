// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DODFeatureCategories",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DODFeatureCategories", targets: ["DODFeatureCategories"])
    ],
    dependencies: [
        .package(path: "../DODDomain"),
        .package(path: "../DODSupport"),
        .package(path: "../DODDesignSystem"),
        .package(path: "../DODAnalytics"),
        .package(path: "../DODNetworking"),
        .package(path: "../DODPersistence"),
        // Test-only — top-level screen visual regression (US-18 / T-332).
        // Pin matches `DODDesignSystem/Package.swift` so the package graph
        // resolves a single `swift-snapshot-testing` version.
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0"),
    ],
    targets: [
        .target(
            name: "DODFeatureCategories",
            dependencies: [
                "DODDomain",
                "DODSupport",
                "DODDesignSystem",
                "DODAnalytics",
                "DODNetworking",
                "DODPersistence",
            ]
        ),
        .testTarget(
            name: "DODFeatureCategoriesTests",
            dependencies: [
                "DODFeatureCategories",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            resources: [.process("__Snapshots__")]
        ),
    ]
)
