// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DODDesignSystem",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DODDesignSystem", targets: ["DODDesignSystem"])
    ],
    targets: [
        // Resources directive will be added back in T-030 when the colors asset
        // catalog lands. SwiftPM rejects an empty Resources bundle on iOS.
        .target(name: "DODDesignSystem"),
        .testTarget(name: "DODDesignSystemTests", dependencies: ["DODDesignSystem"]),
    ]
)
