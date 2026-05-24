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

6. **CI must be green** before merge. The four-layer test pyramid (L1–L4 per constitution §6) runs on every PR.

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

## Local checks before pushing

```bash
bin/format.sh                                  # swift-format
swiftlint                                       # lint
xcodebuild -scheme DODApp -destination 'platform=iOS Simulator,name=iPhone 15' build test
```

If you're in a hurry, at minimum run `bin/format.sh` and `swiftlint`. CI will catch the rest, but you'll iterate faster locally.
