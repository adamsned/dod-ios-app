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
        .testTarget(name: "DODFeatureRecipeDetailTests", dependencies: ["DODFeatureRecipeDetail"]),
    ]
)
