// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DODIntegrationTests",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DODIntegrationTests", targets: ["DODIntegrationTests"])
    ],
    dependencies: [
        .package(path: "../DODDomain"),
        .package(path: "../DODNetworking"),
    ],
    targets: [
        // Empty source target so the package is valid; everything lives in Tests/.
        .target(name: "DODIntegrationTests"),
        .testTarget(
            name: "DODIntegrationTestsTests",
            dependencies: [
                "DODIntegrationTests",
                "DODDomain",
                "DODNetworking",
            ]
        ),
    ]
)
