# Contributing

This repo is spec-first ([`specs/constitution.md`](specs/constitution.md)) and operates as a small team. Workflow below keeps history clean and the constitution honored.

## Workflow

1. **Pull main first.**

   ```bash
   git switch main
   git pull --rebase
   ```

2. **Branch from main.** Naming follows [`specs/constitution.md`](specs/constitution.md) §11:
   - `feat/T-NNN-short-slug` — new feature, ties to a task ID
   - `fix/T-NNN-short-slug` — bug fix
   - `spec/<feature>-<change>` — spec-only changes (constitution amendment, new spec, clarification)
   - `chore/<what>` — repo housekeeping (CI, docs, tooling)

3. **Push the branch early** so the other person can see what you're working on:

   ```bash
   git push -u origin <branch-name>
   ```

   The `-u` flag sets upstream tracking so future `git push` / `git pull` Just Work.

4. **Commit messages** are conventional:
   - `feat(T-NNN): short summary` for features
   - `fix(T-NNN): short summary` for fixes
   - `docs(spec):` / `chore:` / `test:` etc.
   - Reference T-IDs and AC-IDs in the body where relevant.

5. **Open a PR**, don't merge to main directly. Use `gh pr create` or the GitHub UI.
   - PR title matches the convention: `feat(T-NNN): summary`.
   - PR body cites the T-IDs **and** the AC-IDs it implements (per [`specs/constitution.md`](specs/constitution.md) §11).
   - Request review from the relevant code owner (see [`.github/CODEOWNERS`](.github/CODEOWNERS)).

6. **CI must be green** before merge. L1–L4 of the [test pyramid](specs/constitution.md#6-testing--required-for-every-pr) run on every PR; L5 (end-to-end user journeys) runs only when the PR carries the `e2e` label, on `push` to `main`, on `workflow_dispatch`, and nightly. See ["Does my PR need E2E?"](#does-my-pr-need-e2e) below.

7. **Merge style:** squash for `feat/`/`fix/` (one PR = one commit on main), merge commit for multi-task clusters that need history preserved.

8. **Delete the branch** after merge.

## What goes through a PR vs. direct push

**Always PR:**
- Any code change in `App/`, `Packages/`, `LiveActivity/`, `UITests/`, `Marketing/`
- Any change to `specs/` (these are versioned requirements — they deserve review)
- Any change to `.github/workflows/`, `project.yml`, `.swiftlint.yml`, `.swift-format`, `bin/`
- Any constitution amendment

**Direct push to main acceptable (use sparingly):**
- Fixing a typo in a README that's already merged
- Hotfixing a broken CI yaml when CI itself is wedged

When in doubt: open a PR. The cost is low; the review catches things.

## Spec changes precede code changes

If implementation reveals a spec gap, stop and amend the spec first. Do not paper over divergence in code. See the `spec-orchestrator` agent at [`.claude/agents/spec-orchestrator.md`](.claude/agents/spec-orchestrator.md) for the full phase discipline.

## Does my PR need E2E?

The L5 end-to-end user-journey suite (`DODAppE2ETests`) runs the seed five journeys against a real simulator (open → tap recipe → see detail; search → tap → see detail; save → confirm → unsave → empty state; Cook Mode walk + exit; widget deep-link probe). It's slower than the L1–L4 layers and runs only on PRs that opt in via the `e2e` label.

**Apply the `e2e` label** if your PR touches any of:

- [ ] **Navigation / routing** — tab bar order, `NavigationStack` paths, deep-link parser, `RootView.onOpenURL`.
- [ ] **Persistence schema** — SwiftData model edits, migration steps, `CachedRecipe` / `CachedListPage` shape changes.
- [ ] **Composition root** — `App/AppDependencies.swift`, `App/DODApp.swift`, `App/RootView.swift`.
- [ ] **Widget extension** — anything under `Widget/` or `LiveActivity/`, plus the host-side `WidgetSnapshotStore` / `WidgetImageBridge` writers.
- [ ] **Cook Mode state machine** — `CookModeView`, `CookModeViewModel`, the ingredient-check flow.
- [ ] **Comments / ratings submission** — `WPCommentsClient`, `WPRMRatingsClient`, the composer flows.
- [ ] **App Intents / Spotlight** — `RecipeAppIntents`, `DeepLinkIntent`, the spotlight indexer.
- [ ] **Onboarding flow** — the welcome sheet, `RootView.welcomeBullets`, the `dod.onboardingCompletedV1` UserDefaults flag.

**Don't apply the `e2e` label** if your PR is:

- Pure docs/spec (anything under `specs/` or `Marketing/` only).
- Tests-only changes (adding L1/L2 tests, re-recording L4 baselines).
- Lint/format/CI-yaml fixes — *except* changes to the `test-e2e` job itself, which should self-test.
- A single-package refactor with no behavior change.
- A bug fix proven by a regression test at L1 or L2.

When in doubt, apply the label — it just runs more CI; it doesn't change anything else.

See [`specs/dod-ios-app/test-pyramid-audit.md`](specs/dod-ios-app/test-pyramid-audit.md) for the full layer matrix and [`specs/dod-ios-app/clarifications.md`](specs/dod-ios-app/clarifications.md) CL-58 for the rationale behind selective gating.

## Local checks before pushing

```bash
bin/format.sh                                  # swift-format
swiftlint                                       # lint
xcodebuild -scheme DODApp -destination 'platform=iOS Simulator,name=iPhone 17' build test
```

If your PR will carry the `e2e` label, also run the L5 suite locally to catch the same journeys CI will run:

```bash
xcodebuild -scheme DODApp \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DODAppE2ETests test
```

(Optional pre-push — CI catches failures either way, but iterating locally is faster than waiting on a runner.)

If you're in a hurry, at minimum run `bin/format.sh` and `swiftlint`. CI will catch the rest, but you'll iterate faster locally.
