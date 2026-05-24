# App Icon — v1.0

**Status:** Placeholder icon shipped on `feat/app-icon-placeholder` so the
App Store submission isn't blocked. Owner should replace
`App/Assets.xcassets/AppIcon.appiconset/AppIcon.png` with real branding
before submitting v1.0.

## What ships today (placeholder)

A 1024×1024 PNG pictogram of a cast-iron skillet (top-down view) rendered
with ImageMagick:

- Cream background `#FAF6EE` (matches `DODColor.cream`)
- Cast-iron-brown skillet rim and handle `#3D2B1F`
  (matches `DODColor.castIronBrown`)
- Burnt-orange seasoning ring `#C56A24`
  (matches `DODColor.burntOrange`)
- No text (Apple "no text on icon" guideline)
- No transparency, 8-bit sRGB (App Store requirement)

The pictogram reads cleanly at the smallest displayed size (60×60) because
the focal element is well inside the safe area.

## Where it lives

```
App/Assets.xcassets/
├── Contents.json
└── AppIcon.appiconset/
    ├── Contents.json   # single 1024 reference, Xcode 14+ format
    └── AppIcon.png     # 1024×1024 sRGB, no alpha
```

`project.yml` sets `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` on the
DODApp target. The `App` folder is already in `sources:`, so XcodeGen
picks up the catalog automatically — no project.yml change required.

## How to replace with real branding

1. Create a single 1024×1024 PNG with the Dutch Oven Daddy brand
   artwork on a solid background (Apple no longer accepts transparency
   for app icons).
2. Replace `App/Assets.xcassets/AppIcon.appiconset/AppIcon.png` with
   the new file. Keep the filename — `Contents.json` references it
   by name.
3. (Optional) For iOS 18+ icon customization, add **Dark** and
   **Tinted** variants in Xcode → drag into the dark/tinted slots
   of the `AppIcon.appiconset`. Recommended but not required for v1.

## Design guidance for the replacement

- Keep the focal element well inside the safe area — at 60×60 (the
  smallest displayed size) detail vanishes.
- No text on the icon — App Store enforces a "no text" guideline.
- Warm earth tone background to match the in-app palette
  (`DODColor.cream` or `DODColor.castIronBrown` work well).
- The blog already has a brand logo; the simplest path is to use that
  on a solid cream/brown background.

## When this can be skipped

Never — App Store rejects builds without an app icon. The placeholder
covers that gate today; the replacement is for brand polish, not for
shipping.
