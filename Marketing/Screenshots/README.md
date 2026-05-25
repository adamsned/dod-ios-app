# App Store Screenshots — v1.0

**Status:** T-181 — directory + checklist staged; capture happens in Xcode/simulator.

## Required device sizes

Apple requires screenshots for the largest device per family. As of iOS 17+:

- [ ] **iPhone 6.7"** — iPhone 16 Pro Max (or iPhone 15 Pro Max). 1290 × 2796 px.
- [ ] **iPhone 6.5"** — only required if you ever supported iPhone 8/X line; iOS 17+ apps can skip.
- [ ] **iPad 13"** — iPad Pro 12.9" (6th gen). 2064 × 2752 px.

Marketing minimum: **2 per device**. Recommended: **5 per device** to fill the carousel.

## What to capture

For each device size, capture these screens in this order (so the carousel tells a story):

1. **Feed** with a couple of clearly-photographed recipes in view. Status bar should show a clean time and full battery — use simulator's Status Bar override.
2. **Recipe detail** (something visually appealing — the bourbon berry brown sugar cake is a known good one). Scrolled so the hero image and the start of the ingredients list are both visible.
3. **Recipe detail** scrolled to the instructions, ideally with one ingredient checked off so the UI tells you what's interactive.
4. **Search** showing a search like "skillet" with multiple matched results.
5. **Saved** with 3–4 saved recipes, plus the home button glimpse showing the bookmark-filled state.

## How to capture

```bash
# In the simulator, open the app, navigate to the screen, then:
xcrun simctl io booted screenshot ~/Developer/DODApp/Marketing/Screenshots/iphone-6.7-feed.png
```

Or use Xcode → Devices → screenshot button.

Status bar — clean it up before each shot:

```bash
xcrun simctl status_bar booted override \
    --time "9:41" \
    --batteryState charged \
    --batteryLevel 100 \
    --cellularBars 4 \
    --wifiBars 3
```

## File naming

```
{device}-{order}-{screen}.png

Examples:
iphone-6.7-1-feed.png
iphone-6.7-2-detail-hero.png
iphone-6.7-3-detail-instructions.png
ipad-13-1-feed.png
ipad-13-2-detail.png
```

This convention sorts correctly when bulk-uploading to App Store Connect.

## Pre-flight checks

- [ ] App is built in Release configuration (so Debug overlay isn't visible)
- [ ] Sample data on screen makes sense (no test placeholders, no "Lorem ipsum")
- [ ] Status bar overridden as above
- [ ] No notifications visible
- [ ] No keyboard accidentally visible
- [ ] Light mode AND dark mode versions captured separately (App Store accepts both — use light for primary slot)
