// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DODSupport",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DODSupport", targets: ["DODSupport"])
    ],
    dependencies: [
        .package(path: "../DODDomain")
    ],
    targets: [
        .target(
            name: "DODSupport",
            dependencies: ["DODDomain"]
        ),
        .testTarget(name: "DODSupportTests", dependencies: ["DODSupport"]),
    ]
)
