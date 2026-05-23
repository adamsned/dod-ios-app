// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DODPersistence",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DODPersistence", targets: ["DODPersistence"])
    ],
    dependencies: [
        .package(path: "../DODDomain")
    ],
    targets: [
        .target(
            name: "DODPersistence",
            dependencies: ["DODDomain"]
        ),
        .testTarget(name: "DODPersistenceTests", dependencies: ["DODPersistence"])
    ]
)
