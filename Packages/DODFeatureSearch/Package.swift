// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DODFeatureSearch",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DODFeatureSearch", targets: ["DODFeatureSearch"])
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
            name: "DODFeatureSearch",
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
            name: "DODFeatureSearchTests",
            dependencies: [
                "DODFeatureSearch",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            resources: [.process("__Snapshots__")]
        ),
    ]
)
