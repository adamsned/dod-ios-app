// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DODDesignSystem",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DODDesignSystem", targets: ["DODDesignSystem"])
    ],
    targets: [
        .target(
            name: "DODDesignSystem",
            resources: [.process("Resources")]
        ),
        .testTarget(name: "DODDesignSystemTests", dependencies: ["DODDesignSystem"])
    ]
)
