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
        .testTarget(name: "DODFeatureSearchTests", dependencies: ["DODFeatureSearch"]),
    ]
)
