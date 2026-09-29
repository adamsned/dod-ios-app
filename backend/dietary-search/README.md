# Dietary Search — design & backend spec

**Status:** proposal (for Ned to review) · **Author:** Spencer + Claude · **Date:** 2026-06-24

Let app users filter recipes by **dietary need** in Search — gluten-free, vegetarian,
low-carb, high-protein, and so on — with chips that are **distinct from the category
browse list** and that **never mislead** (a "gluten free" chip must not return pasta).

This spec splits the work: a small, one-time **backend change + ongoing content tagging**
(Ned's side, WordPress/WPRM) and the **app filter UI** (Spencer/Claude's side). The app part
is ready to build the moment the backend field below exists.

---

## 1. Why this needs backend work first (what we verified, 2026-06-24)

We probed the live `dutchovendaddy.com` WP REST API. The short version: the *infrastructure*
exists but the *data* doesn't, and there's no honest app-only shortcut.

- **The diet taxonomy exists but is nearly empty.** `wprm_suitablefordiet` has real recipes
  for only **Gluten Free (5), Vegetarian (2), Low Lactose (1)** — every other term
  (Vegan, Low Fat, Low Calorie, Diabetic, …) is **0**. There is **no "Low Carb" or
  "High Protein" term at all**.
- **It lives on the recipe, not the post.** The taxonomy is on the `wprm_recipe` object,
  but the app searches/lists `post`s. Filtering posts by it is **silently ignored** —
  `posts?wprm_suitablefordiet=gluten-free`, `…=vegetarian`, and no filter all return the
  **same 255 posts**.
- **Posts carry no tags.** `post_tag` is essentially empty on the recipe posts.
- **Text search is actively misleading**, so "just search the words" is off the table.
  WP `?search=` matches any post that *mentions* the words:
  - `?search=gluten free` → **112 hits**, top results include **Chicken Florentine _Pasta_**
  - `?search=dairy free` → **71 hits**, top result is the **_Creamy_** Chicken Florentine
  - `?search=low carb` → **21 hits**, top result is **Beer-Battered Fish** (batter = carbs)

  Shipping that would tell someone with coeliac disease that pasta is gluten-free. Not an option.

**Conclusion:** an accurate dietary filter must be taxonomy-backed, which needs (a) recipes
**tagged**, and (b) the tags **exposed on the post listing** the app queries.

---

## 2. Backend — what to add (Ned)

### 2a. Expose the recipe's diet on the post listing (one-time, ~20 lines)

The app gets recipes from `/wp/v2/posts`. Add a custom REST field so each post returns its
recipe's dietary slugs. Drop this in a tiny **mu-plugin** (`wp-content/mu-plugins/dod-dietary.php`)
or `functions.php`:

```php
<?php
/**
 * Exposes each recipe post's WPRM dietary tags on the REST `post` object as
 * `dietary: ["gluten-free", ...]`, so the DOD app can display + filter by them.
 */
add_action('rest_api_init', function () {
    register_rest_field('post', 'dietary', [
        'get_callback' => function ($post) {
            if (!class_exists('WPRM_Recipe_Manager')) {
                return [];
            }
            // WPRM: the recipe(s) embedded in this post. Confirm the method name
            // for your WPRM version; the parse-from-content fallback is noted below.
            $recipe_ids = WPRM_Recipe_Manager::get_recipe_ids_from_post($post['id']);

            $slugs = [];
            foreach ($recipe_ids as $rid) {
                // Built-in "Suitable for Diet" taxonomy (gluten-free, vegetarian, …).
                $diet = wp_get_post_terms($rid, 'wprm_suitablefordiet', ['fields' => 'slugs']);
                if (!is_wp_error($diet)) {
                    $slugs = array_merge($slugs, $diet);
                }
                // Low-Carb / High-Protein via a controlled keyword convention
                // (WPRM's diet list is schema.org and has no low-carb/high-protein).
                $kw = wp_get_post_terms($rid, 'wprm_keyword', ['fields' => 'slugs']);
                if (!is_wp_error($kw)) {
                    $allowed = ['low-carb', 'high-protein'];
                    $slugs = array_merge($slugs, array_values(array_intersect($kw, $allowed)));
                }
            }
            return array_values(array_unique($slugs));
        },
        'schema' => [
            'type'    => 'array',
            'items'   => ['type' => 'string'],
            'context' => ['view', 'embed'],
        ],
    ]);
});
```

- **Confirm the WPRM accessor** for your version. The documented public method is
  `WPRM_Recipe_Manager::get_recipe_ids_from_post($post_id)`. If that's unavailable, the
  content-parse fallback is
  `WPRM_Recipe_Manager::get_recipe_ids_from_content(get_post($post['id'])->post_content)`.
- That's the **only** change needed for v1. Every `/wp/v2/posts` item then returns e.g.
  `"dietary": ["gluten-free", "vegetarian"]`, and the app filters on it client-side (exactly
  how it already filters cook-time). No new endpoints, no query-arg plumbing.

### 2b. (Phase 2, optional) Server-side filtering

If you later want `posts?dietary=gluten-free` to filter on the **server** (nicer at scale):
on recipe save, mirror the diet slugs into a parent-post meta `_dod_dietary` (hook WPRM's
recipe-save), then add a `rest_post_query` filter that turns `?dietary=` into a `meta_query`.
**Not needed for v1** — the catalog is ~255 posts, so client-side filtering in the app is fine.

---

## 3. Content — tagging (Ned, ongoing)

The chips are only as honest as the tags. The app shows a chip **only for diets that
actually have recipes**, so under-tagging just means fewer chips, never wrong results.

- **Use WPRM's "Suitable for Diet"** field on each recipe for the standard diets it supports:
  Gluten Free, Vegetarian, Vegan, Low Fat, Low Calorie, Low Lactose, Diabetic, Halal, etc.
  (WPRM's list is schema.org-based.)
- **Low Carb / High Protein** aren't in WPRM's diet list. Pick one convention and stick to it:
  - add them as **custom terms** in the diet taxonomy if your WPRM allows it, **or**
  - use a **controlled `wprm_keyword`** set — exactly the slugs `low-carb`, `high-protein`
    (the snippet in §2a already whitelists those two).
- **Recommended starting vocabulary** (slugs the app will turn into chips):
  `gluten-free`, `vegetarian`, `vegan`, `dairy-free`, `low-carb`, `high-protein`.
  Start with whatever you can tag accurately; the list grows on its own.
- A first pass on the **top ~50 most-viewed recipes** makes the feature genuinely useful on
  day one.

---

## 4. Allergens (e.g. "Peanut Free") — handled separately, safety-first

**Not in v1, and never inferred.** "Peanut free" is a *safety* claim, not a preference. We
must not derive it from the ingredient list — hidden derivatives, "may contain," and
cross-contamination make text/ingredient inference unsafe. A wrong "peanut free" label could
genuinely hurt someone.

If we add allergen filters later: a **separate, explicit, authoritative** allergen field that
Ned tags deliberately, plus an **"always verify the recipe — cross-contamination is possible"**
disclaimer in the app. Until that exists, the app will not imply any recipe is allergen-free.

---

## 5. App — what Claude builds (once §2a lands)

Mirrors the existing Search filter architecture (`SearchFilters` already composes a category
filter + a cook-time range + recently-viewed):

- Add `dietary: Set<String>` to `SearchFilters`, applied as a client-side post-filter on the
  new `post.dietary` field (same shape as the cook-time predicate in `SearchFilters.apply`).
- A **"Dietary" chip row** in Search, **data-driven** from the available terms (read from
  `/wp/v2/wprm_suitablefordiet` + the keyword set, count > 0) — so a chip can never show a diet
  with no recipes. This is a **distinct dimension** from the category browse list, which fixes
  the current overlap (today's "Try" chips are just top categories).
- Bonus once the field exists: small **dietary badges** on recipe cards / detail.

The app work is the easy half and ships behind whatever's tagged. CL/T spec entries get added
when it's implemented.

---

## 6. The contract (so the two sides stay in sync)

- **`post.dietary`** — array of lowercase slugs from the controlled vocabulary, e.g.
  `["gluten-free", "vegetarian", "low-carb"]`. Present on every `/wp/v2/posts` item.
- **Available chip terms** — the app reads the diet taxonomy + the whitelisted keyword set and
  renders only `count > 0`.

---

## 7. Recommended order (fast path)

1. **Ned:** add the `dietary` REST field (§2a) — ~20 lines, minutes to ship. Tag Gluten Free +
   Vegetarian on the popular recipes (some already done).
2. **Claude:** build the Dietary chip row + filter against the field. → Gluten-Free /
   Vegetarian filtering works, accurately, and grows automatically.
3. **Ned:** add Low Carb / High Protein (custom terms or the keyword convention) + keep tagging.
4. **Later:** allergens, carefully, per §4.
