// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DODDesignSystem",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DODDesignSystem", targets: ["DODDesignSystem"])
    ],
    dependencies: [
        // Test-only — visual regression per constitution §6 L4.
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0")
    ],
    targets: [
        .target(
            name: "DODDesignSystem",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "DODDesignSystemTests",
            dependencies: [
                "DODDesignSystem",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            resources: [.process("__Snapshots__")]
        ),
    ]
)
