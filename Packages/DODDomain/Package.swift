// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DODDomain",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DODDomain", targets: ["DODDomain"])
    ],
    targets: [
        .target(name: "DODDomain"),
        .testTarget(name: "DODDomainTests", dependencies: ["DODDomain"])
    ]
)
