// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DODIntelligence",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DODIntelligence", targets: ["DODIntelligence"])
    ],
    dependencies: [
        .package(path: "../DODDomain"),
        .package(path: "../DODSupport"),
    ],
    targets: [
        .target(
            name: "DODIntelligence",
            dependencies: [
                "DODDomain",
                "DODSupport",
            ]
        ),
        .testTarget(
            name: "DODIntelligenceTests",
            dependencies: ["DODIntelligence"]
        ),
    ]
)
