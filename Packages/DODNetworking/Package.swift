// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DODNetworking",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DODNetworking", targets: ["DODNetworking"])
    ],
    dependencies: [
        .package(path: "../DODDomain"),
        .package(path: "../DODSupport"),
    ],
    targets: [
        .target(
            name: "DODNetworking",
            dependencies: ["DODDomain", "DODSupport"]
        ),
        .testTarget(
            name: "DODNetworkingTests",
            dependencies: ["DODNetworking"],
            resources: [.process("Fixtures")]
        ),
    ]
)
