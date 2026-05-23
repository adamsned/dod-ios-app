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
            ]
        ),
        .testTarget(name: "DODFeatureFeedTests", dependencies: ["DODFeatureFeed"]),
    ]
)
