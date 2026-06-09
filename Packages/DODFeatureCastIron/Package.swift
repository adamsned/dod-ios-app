// swift-tools-version: 6.0
import PackageDescription

// DUT-13 Cast Iron Photo Scanner. STAGED for iOS 27 (WWDC 2026 Foundation
// Models image input). Parked off the shipping feature set until iOS 27 is
// public - see README. The on-device vision + Private Cloud Compute
// diagnosers live behind the `CASTIRON_IOS27` compilation flag (off by
// default) because the `Attachment` image API ships only in the iOS 27 SDK.
// Build the staged code with: -Xswiftc -DCASTIRON_IOS27 (Xcode 27 beta+).
let package = Package(
    name: "DODFeatureCastIron",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DODFeatureCastIron", targets: ["DODFeatureCastIron"])
    ],
    targets: [
        .target(name: "DODFeatureCastIron"),
        .testTarget(
            name: "DODFeatureCastIronTests",
            dependencies: ["DODFeatureCastIron"]
        ),
    ]
)
