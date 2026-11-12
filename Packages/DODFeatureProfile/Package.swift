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
        // DUT-276 — Sign in with Google. The GIDSignIn-backed provider
        // (`GIDSignInProvider`) is UIKit-gated, so the product is linked on iOS
        // only; the macOS slice (L1 `swift test`) never pulls it. Config (client
        // ID + reversed-client-ID URL scheme) lives in the app Info.plist.
        .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "8.0.0"),
        // Signs the profile in to Firebase too, so saved recipes sync with the
        // Android app for the same Apple or Google account (iOS only, like GoogleSignIn).
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "12.0.0"),
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
                .product(
                    name: "GoogleSignIn",
                    package: "GoogleSignIn-iOS",
                    condition: .when(platforms: [.iOS])
                ),
                .product(
                    name: "FirebaseAuth",
                    package: "firebase-ios-sdk",
                    condition: .when(platforms: [.iOS])
                ),
                .product(
                    name: "FirebaseFirestore",
                    package: "firebase-ios-sdk",
                    condition: .when(platforms: [.iOS])
                ),
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
