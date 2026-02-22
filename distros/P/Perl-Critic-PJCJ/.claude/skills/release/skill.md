---
name: release
description: >
  Release workflow for Perl-Critic-PJCJ. Use when preparing or performing
  a CPAN release. Both commands live in utils/run and support --dryrun.
user_invocable: true
---

# Release workflow for Perl-Critic-PJCJ

## Commands

- **`make release`** — full release: creates a GitHub ticket,
  branch, PR, merges, then runs `dzil release` (CPAN upload, tag,
  push). Confirmation checkpoints before every external action.
- **`utils/run release-ticket`** — creates only the ticket, branch,
  and PR. Use when you want to prepare without releasing.

Both support `--dryrun` and must be run from `main` with a clean
working tree (excluding `Changes.md`, which should be uncommitted).
`release` also requires entries under `{{$NEXT}}` in `Changes.md`.

See `docs/release.md` for the full developer guide.
