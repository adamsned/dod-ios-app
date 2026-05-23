// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DODAnalytics",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DODAnalytics", targets: ["DODAnalytics"])
    ],
    dependencies: [
        // TelemetryDeck is wired in T-041.
        // .package(url: "https://github.com/TelemetryDeck/SwiftSDK", from: "2.0.0")
    ],
    targets: [
        .target(name: "DODAnalytics"),
        .testTarget(name: "DODAnalyticsTests", dependencies: ["DODAnalytics"])
    ]
)
