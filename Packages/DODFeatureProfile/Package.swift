// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DODFeatureProfile",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DODFeatureProfile", targets: ["DODFeatureProfile"])
    ],
    dependencies: [
        .package(path: "../DODSupport"),
        .package(path: "../DODDesignSystem"),
        // Test-only — L4 visual regression for the avatar + Settings row
        // surfaces (US-44 / T-739). Pin matches `DODDesignSystem/Package.swift`
        // so the package graph resolves a single `swift-snapshot-testing`
        // version.
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0"),
    ],
    targets: [
        .target(
            name: "DODFeatureProfile",
            dependencies: [
                "DODSupport",
                "DODDesignSystem",
            ]
        ),
        .testTarget(
            name: "DODFeatureProfileTests",
            dependencies: [
                "DODFeatureProfile",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            resources: [.process("__Snapshots__")]
        ),
    ]
)
