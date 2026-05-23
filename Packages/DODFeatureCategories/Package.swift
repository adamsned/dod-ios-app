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
        .package(path: "../DODPersistence")
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
                "DODPersistence"
            ]
        ),
        .testTarget(name: "DODFeatureCategoriesTests", dependencies: ["DODFeatureCategories"])
    ]
)
