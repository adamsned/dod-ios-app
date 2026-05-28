// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DODFeatureRecipeDetail",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DODFeatureRecipeDetail", targets: ["DODFeatureRecipeDetail"])
    ],
    dependencies: [
        .package(path: "../DODDomain"),
        .package(path: "../DODSupport"),
        .package(path: "../DODDesignSystem"),
        .package(path: "../DODAnalytics"),
        .package(path: "../DODNetworking"),
        .package(path: "../DODPersistence"),
        // Test-only — visual regression for the Cook Mode Live Activity
        // surfaces (US-11). See constitution §3 (approved dep) + §6 L4.
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0"),
    ],
    targets: [
        .target(
            name: "DODFeatureRecipeDetail",
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
            name: "DODFeatureRecipeDetailTests",
            dependencies: [
                "DODFeatureRecipeDetail",
                "DODAnalytics",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            resources: [.process("__Snapshots__")]
        ),
    ]
)
