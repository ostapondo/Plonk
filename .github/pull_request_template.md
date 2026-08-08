<!--
CONTRIBUTING.md has the long version. Delete any line that does not apply.
-->

## What changed, and why

<!-- One paragraph. The why matters more than the what; the diff has the what. -->

## What you ran

<!--
The loop CI runs, from the repository root. Paste the ones you ran:

  (cd App && swift build)
  ./scripts/test.sh
  (cd mcp && npm ci && npm run typecheck)

None of them need a signing certificate. Say so if you also built and launched
Plonk.app, and on which macOS version and monitor arrangement.
-->

## Checks

- [ ] `swift build` passes on every commit in the branch, not just the last one
- [ ] New logic is covered in `App/Tests/plonkTests/`, or it is not the kind that can be
- [ ] Commits use `feat:` / `fix:` / `docs:` / `chore:` / `refactor:`
- [ ] If this touches the network, the permissions, the entitlements or the update path, `README.md` and `SECURITY.md` still tell the truth — fixed in this PR if not
- [ ] Screenshots below for anything visual
