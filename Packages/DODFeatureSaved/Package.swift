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
        .package(path: "../DODPersistence")
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
                "DODPersistence"
            ]
        ),
        .testTarget(name: "DODFeatureSavedTests", dependencies: ["DODFeatureSaved"])
    ]
)
