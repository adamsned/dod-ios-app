# App Store Screenshots — v1.0

**Status:** T-181 / DUT-1210 — captured 2026-10-10 from `main` @ `123ebabf` (Debug simulator build, live blog content, light mode). Not yet uploaded to App Store Connect. Framing/captions and the final carousel pick are Spencer's design call.

## Required device sizes

Apple requires screenshots for the largest device per family:

- [x] **iPhone 6.9"** — iPhone 17 Pro Max. 1320 × 2868 px.
- [x] **iPad 13"** — iPad Pro 13-inch (M5). 2064 × 2752 px.

App Previews (video) are optional and not captured.

## What is captured

Six screens per device, in carousel order:

1. **Feed** — Recipes & Articles grid.
2. **Recipe detail** — Cast Iron Hamburger Steak with Mushroom Gravy, hero + intro.
3. **Cook Mode** — step 4 of 10 with the 4:00 step timer.
4. **Heat Coach** — coal count for a 12" oven, Even style.
5. **First Cookout** — the guided path with "Start Here".
6. **Saved** — saved recipes grid (4 on iPhone, 6 on iPad).

On iPad, Heat Coach and First Cookout present as a form sheet over Cooking Tools; that is the current UI, not a capture artifact.

## How to capture

Build and install a simulator build from `main`, launch with onboarding suppressed, then navigate by hand and screenshot each screen:

```bash
SIMCTL_CHILD_DOD_SUPPRESS_ONBOARDING=1 xcrun simctl launch booted com.dutchovendaddy.DODApp
xcrun simctl io booted screenshot Marketing/Screenshots/iphone-6.9-1-feed.png
```

Status bar — clean it up before the first shot:

```bash
xcrun simctl status_bar booted override \
    --time "9:41" \
    --batteryState charged \
    --batteryLevel 100 \
    --cellularBars 4 \
    --wifiBars 3
```

`simctl` writes PNGs with an alpha channel, which App Store Connect rejects. Strip it before committing:

```bash
magick mogrify -alpha off -strip Marketing/Screenshots/*.png
```

`UITests/Screenshots/ScreenshotTests.swift` is the May 2026 automated harness. It walks the old five-screen set (Feed, Detail x2, Search, Saved) against the old UI and was not used for this capture.

## File naming

```
{device}-{order}-{screen}.png

iphone-6.9-1-feed.png
iphone-6.9-2-recipe-detail.png
iphone-6.9-3-cook-mode.png
iphone-6.9-4-heat-coach.png
iphone-6.9-5-first-cookout.png
iphone-6.9-6-saved.png
ipad-13-1-feed.png
...
```

This convention sorts correctly when bulk-uploading to App Store Connect.

## Pre-flight checks

- [x] Sample data on screen makes sense (no test placeholders, no "Lorem ipsum")
- [x] Status bar overridden as above
- [x] No notifications visible
- [x] No keyboard accidentally visible
- [x] No alpha channel (`sips -g hasAlpha` reports `no`)
- [ ] Dark mode set (optional; light is the primary slot)
