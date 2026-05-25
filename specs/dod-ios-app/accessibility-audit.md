# Accessibility Audit — v1.0

**Status:** Cluster H (T-160, T-161, T-162) — code-side audit complete; in-simulator verification still required.

**Governs:** constitution §7, spec CC-1.

## What's covered in code

### VoiceOver labels (T-161)

| Surface | Label source | Notes |
|---|---|---|
| RecipeCard | `accessibilityElement(children: .combine)` with composite label of title + excerpt + time | DesignSystem |
| OfflineBanner | "Offline. {message}" | DesignSystem |
| Snackbar | Combined message + optional action title | DesignSystem |
| EmptyState icon | `accessibilityHidden(true)` (decorative) | DesignSystem |
| IngredientCheckRow | Label = ingredient text, value = "checked"/"unchecked", trait `.isSelected` when checked | RecipeDetail |
| InstructionStepView | Combined "Step N. {text}" | RecipeDetail |
| RecipeDetailView hero image | Label = recipe title | RecipeDetail |
| Save bookmark button | "Save recipe" / "Unsave recipe" toggle label | RecipeDetail |
| Share button | "Share recipe" | RecipeDetail |
| Category list row | "{name}, {count} recipes" | Categories |
| Loading skeleton group | `accessibilityElement(children: .ignore)` + "Loading recipes" container label | Feed |

### Dynamic Type (T-160)

- All text in `DesignSystem/Typography.swift` uses `Font.system(.style)`. Apple's system fonts scale automatically with Dynamic Type up to AX5.
- No hard-coded point sizes outside the icon glyphs (which are explicitly fixed for layout).
- Skeleton heights are hard-coded but proportional — at AX5 they may need adjustment but won't truncate content.

### Color contrast (T-162)

The `Colors.xcassets` palette has light + dark variants for every semantic token. Manual contrast targets (per WCAG AA):

| Pair | Light | Dark | Status |
|---|---|---|---|
| Label on Surface | #2C2C2C on #FAF6EE | #E6DECF on #1B140E | ✓ Both ≥ 12:1 |
| LabelSecondary on Surface | #6B6B6B on #FAF6EE | #A8A39A on #1B140E | ✓ Both ≥ 4.5:1 |
| Cream on CastIronBrown (banner) | #FAF6EE on #3D2B1F | same in dark | ✓ ≥ 11:1 |
| Cream on BurntOrange (accent button) | #FAF6EE on #C56A24 | same | Need to verify in Accessibility Inspector |
| WarmGold on CastIronBrown (snackbar Undo) | #D4A24C on #3D2B1F | same | Need to verify |

### Reduce Motion

- `LoadingSkeleton` checks `@Environment(\.accessibilityReduceMotion)` and renders a static fill when set, instead of the shimmer animation.

## What still needs in-simulator verification

These cannot be checked from source code alone. **Run them before any TestFlight build:**

- [ ] Open every screen in the simulator at Dynamic Type **AX5** — verify no truncation, no overlapping elements, all CTAs reachable. Iterate on font tokens if needed.
- [ ] Run **Accessibility Inspector** (Xcode → Open Developer Tool → Accessibility Inspector) on each screen — should report zero issues per screen.
- [ ] Run VoiceOver (⌘F5 in simulator) through the golden path: Feed → tap recipe → save → back → Saved → open offline. Every interactive element should announce its purpose.
- [ ] Verify the two flagged contrast pairs above with the Color Contrast Calculator in Accessibility Inspector. If either is below WCAG AA, adjust the palette in `Colors.xcassets` and re-snapshot.
- [ ] Toggle Reduce Motion (Settings → Accessibility → Motion) and confirm: skeleton stops shimmering, offline banner uses fade-only transition (not slide), snackbar appears without bounce.

## Out of scope for v1.0

- VoiceOver rotor customization (no custom rotor — system defaults suffice).
- Voice Control command vocabulary (not customized; relies on visible button labels).
- Switch Control (uses standard focus order from layout).
- Large content viewer (system handles for SF Symbol icons; custom icons would need own handling but we have none in v1).

## Updating this audit

When you change a label or contrast token, edit this file in the same PR. The audit is part of the deliverable, not an afterthought (constitution §6, §11).
