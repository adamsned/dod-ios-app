<!--
Thanks for opening a PR! Fill in the sections below.
For tiny doc-only or comment-only changes, you can delete sections that don't apply.
-->

## What changed

<!-- 1–3 sentences. Focus on the "why" more than the "what". -->

## Spec trace

<!--
Reference the spec ID(s) this PR satisfies, e.g.:
- US-13 / AC-13.2 / REG-13 / CL-21
- T-220 in tasks.md
If this is unrelated to a spec item, write "n/a — <reason>".
-->

## How to test

<!--
- [ ] `swift test` in <package(s)>
- [ ] Built and ran on iOS Simulator (state what you exercised)
- [ ] XCUI smoke / snapshot tests pass
-->

## Risk + rollback

<!--
- Risk level: low / medium / high
- If something breaks in production, what's the rollback? (e.g. "revert this commit", "schema migration is reversible", "flag-gated so just flip the flag")
-->

## Reviewer checklist

- [ ] Branch name uses the `<type>/<short-slug>` convention (`feat/`, `fix/`, `chore/`, `docs/`, `test/`, `refactor/`, `spec/`)
- [ ] Commit messages are Conventional Commits style (`feat(scope): …`)
- [ ] No secrets, .env files, signing certs, or `.xcconfig` with API keys committed
- [ ] If touching spec/constitution: clarifications doc updated and trace IDs reused
- [ ] CI is green
