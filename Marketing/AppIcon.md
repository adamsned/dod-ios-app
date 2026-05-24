# App Icon — v1.0

**Status:** **Real brand icon shipped.** Owner-provided "DUTCH OVEN DADDY · CAST
IRON LIVING" circular badge with the dutch oven silhouette, packaged as an
Apple Icon Composer `.icon` bundle.

## Where it lives

```
App/
├── AppIcon.icon/             ← Icon Composer bundle (NOT inside Assets.xcassets)
│   ├── icon.json             ← Layer manifest: solid sRGB-white fill,
│   │                            single glass layer containing "DOD Master.png"
│   │                            at scale 1.05, neutral shadow @ 0.5 opacity,
│   │                            translucency @ 0.5
│   └── Assets/
│       └── DOD Master.png    ← 1048 × 1058, 8-bit/color RGBA source artwork
└── Assets.xcassets/          ← Brand color set; no AppIconSet here anymore
```

`project.yml` keeps `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`. XcodeGen
finds the bundle by basename — because the file is `AppIcon.icon`, Xcode 26
resolves it as the app icon at build time.

## Why `.icon` instead of a flat `.appiconset`

The Icon Composer format (Xcode 26 / iOS 26) lets a single source artwork
auto-generate Light, Dark, and Tinted variants iOS 18+ ships. The bundle
declares:
- A **solid sRGB white fill** for the base canvas (satisfies App Store's
  no-transparency requirement automatically).
- A **glass layer** with neutral shadow + 50% translucency so the system
  composites the badge with the same depth treatment Apple's own app icons
  get on iOS 26.

No code change is required if the artwork is updated — replace
`App/AppIcon.icon/Assets/DOD Master.png`, run `xcodegen generate`, rebuild.

## How to replace artwork later (e.g. seasonal variants)

1. Open Icon Composer (Xcode 26 → File → New → Icon, or `Xcode → Open → AppIcon.icon`).
2. Drop a new 1024 × 1024 (or larger) PNG into the existing layer; tweak
   shadow / translucency / scale in the manifest if desired.
3. Save back to `App/AppIcon.icon`; commit the updated `icon.json` and PNG.
4. Verify the build picks it up: `xcodegen generate && xcodebuild ... build`.

## Verified

- `xcodebuild` for `DODApp` on iPhone 17 simulator (iOS 26.5): **BUILD SUCCEEDED**
- Installed on iPhone 17 simulator, home screen shows the badge with the
  correct circular shape, brown silhouette, and brand outline at full size.
- Screenshot captured at `/tmp/dod-icon-on-home.png` (cream/white background,
  iOS auto-applied the standard rounded-rect mask).

## When this can be skipped

Never — App Store rejects builds without an app icon. v1.0 now ships the
real brand mark.
