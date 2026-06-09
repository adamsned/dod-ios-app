# DODFeatureCastIron - DUT-13 Cast Iron Photo Scanner (iOS 27, STAGED)

**Status: parked. Do not merge to `main` or ship in the iOS 26 feature set
until iOS 27 is public.**

Point the camera at a piece of cast iron; the app diagnoses its condition
(well-seasoned, sticky, rusty, cracked, never-seasoned) and walks through
cleaning + re-seasoning. Linear: DUT-13.

## Why this is on a parking branch

The hero path needs the **iOS 27 Foundation Models image input** (WWDC 2026):
`Attachment(image)` on a `LanguageModelSession`. That symbol ships only in the
iOS 27 SDK (Xcode 27 beta+), which can't be installed in CI or the current
release toolchain (Xcode 26). So the feature is staged here, off the shipping
iOS 26 feature set, until iOS 27 GA.

## What builds + tests today (Xcode 26)

The whole spine compiles and tests with the default flags - no Foundation
Models dependency is pulled in:

- `CastIronCondition`, `CastIronDiagnosis`, `CareStep` - the contract
- `CastIronDiagnoser` protocol + `CastIronImage`
- `CuratedCastIronCare` - offline / pre-iOS-27 fallback content (5 states)
- `CastIronCareService` - tiering + graceful degradation
- Tests for all of the above (11 cases)

```
swift test --package-path Packages/DODFeatureCastIron
```

## What is staged behind `-D CASTIRON_IOS27` (needs Xcode 27 beta)

These files reference the iOS 27-only `Attachment` / Private Cloud Compute
APIs and are excluded from the default build:

- `FoundationModelsCastIronDiagnoser` - on-device vision (iPhone 15 Pro+)
- `PrivateCloudComputeCastIronDiagnoser` - Apple PCC fallback (any iOS 27)
- `CastIronDiagnoserResolver` - device / OS tier selection

Enable once Xcode 27 beta + the iOS 27 SDK are installed:

```
swift build --package-path Packages/DODFeatureCastIron -Xswiftc -DCASTIRON_IOS27
```

These are written against Apple's documented API
(developer.apple.com/videos/play/wwdc2026/241) and are **not yet
compile-checked** - verify exact signatures against the real SDK.

## Privacy posture

On-device vision and Private Cloud Compute keep photos out of any third
party's hands (PCC is Apple-operated and free under 2M downloads), so this
avoids the constitution section 9 conflict the original cloud-LLM option
(Claude / GPT-4V upload) would have tripped. Camera capture still adds an
`NSCameraUsageDescription` key + a privacy-manifest line - owner sign-off
required before ship.

## Remaining before ship (at iOS 27 GA)

- Compile + on-device test the staged diagnosers on a 15 Pro+ / iOS 27 device
- Camera capture UI (AVFoundation / PhotosPicker) + `NSCameraUsageDescription`
- Settings > Tools entry (mirror the DUT-48 Heat Coach) + the walkthrough view
- Wire the package into `project.yml` + the app target
- Privacy-manifest update (camera) + owner sign-off (constitution section 9)
- Dad's "How to Clean and Restore Cast Iron" article (optional deep-link)
