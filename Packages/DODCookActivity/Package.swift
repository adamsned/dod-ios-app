// swift-tools-version: 6.0
import PackageDescription

// DUT-295 — SDK-free leaf module holding the Cook Mode Live Activity payload
// (`CookActivityAttributes`) + its view layouts (`CookActivity*View`), shared by
// the producer (`DODFeatureRecipeDetail`) and the Live Activity app-extension
// (`DODAppLiveActivity`). Extracted so the extension no longer depends on the
// whole `DODFeatureRecipeDetail` feature — which transitively links the
// GoogleSignIn OAuth SDK (`DODFeatureProfile`) into the appex, an App Store risk
// (extension-unsafe `UIApplication.shared` API + binary bloat). Depends only on
// `DODDesignSystem` (tokens for the view layouts).
let package = Package(
    name: "DODCookActivity",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DODCookActivity", targets: ["DODCookActivity"])
    ],
    dependencies: [
        .package(path: "../DODDesignSystem")
    ],
    targets: [
        .target(
            name: "DODCookActivity",
            dependencies: ["DODDesignSystem"]
        ),
        .testTarget(name: "DODCookActivityTests", dependencies: ["DODCookActivity"]),
    ]
)
