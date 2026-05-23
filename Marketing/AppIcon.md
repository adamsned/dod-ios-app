# App Icon — v1.0

**Status:** T-180 — code-side placeholder ready; **icon artwork required from owner**.

## Where it goes

The asset catalog is at:

```
App/Assets.xcassets/AppIcon.appiconset/
```

(Does not yet exist — XcodeGen will reference this path once a non-empty
`AppIcon.appiconset` exists. Currently the `project.yml` sets
`ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` but the catalog is absent.)

## How to add the icon

1. Create a single 1024×1024 PNG with the Dutch Oven Daddy logo on a
   solid background (Apple no longer accepts transparency for app icons).
2. Open `App/Assets.xcassets` in Xcode → right-click → New App Icon →
   drag the 1024 PNG into the "Any Appearance" slot. Xcode auto-generates
   the other size slots.
3. Optionally add **Dark** and **Tinted** variants for iOS 18+ icon
   customization. Recommended but not required for v1.

## Design guidance

- Keep the focal element well inside the safe area — at 60×60 (the
  smallest displayed size) detail vanishes.
- No text on the icon — App Store enforces a "no text" guideline.
- Warm earth tone background to match the in-app palette
  (DODColor.cream or DODColor.castIronBrown work).
- The blog already has a brand logo; the simplest path is to use that
  on a solid cream/brown background.

## When this can be skipped

Never — App Store rejects builds without an app icon. This is the one
visual asset that absolutely blocks submission.
