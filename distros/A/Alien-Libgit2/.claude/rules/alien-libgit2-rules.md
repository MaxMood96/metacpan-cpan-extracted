# Alien::Libgit2 House Rules

Apply to every task in this repository unless explicitly overridden. Bias: caution over
speed on non-trivial work; judgment on trivial ones. Loaded automatically at launch (same
priority as `CLAUDE.md`). Subagents get their conventions from the skills force-loaded via
`briefing.skills` — this file is for the orchestrating agent.

## Engineering discipline

1. **Think before coding** — State assumptions. When uncertain, ask rather than guess.
   Push back when a simpler approach exists. Stop when confused; name what's unclear.
2. **Simplicity first** — Minimum change that solves the problem. Nothing speculative.
3. **Surgical changes** — Touch only what you must. Don't "improve" adjacent code,
   comments or formatting. Match existing style.
4. **Read before you write** — `alienfile` is the whole distribution; read it *and* the
   CI workflows before changing either. They encode the same CMake flags twice on purpose.
5. **Surface conflicts, don't average them** — Contradicting patterns: pick one (more
   recent / more tested), say why, flag the other. Don't blend.
6. **Checkpoint after every significant step** — done / verified / left.
7. **Fail loud** — "Done" is wrong if anything was skipped silently; "tests pass" is wrong
   if only one install path ran.

## Delegation

Depends on whether the Agent/Task tool is available to you.

- **You can spawn subagents** (orchestrating main agent): do NOT touch behavior-relevant
  files yourself — delegate.

  | Task | Agent |
  |---|---|
  | alienfile, share/ tarball, CI workflows, t/, lib/Alien/, POD | `alien-libgit2-worker` (default) |
  | Pre-release audit (CPAN) | `alien-libgit2-release-checker` |

  Your lane: coordinate, inspect, plan, review diffs, run tests, manage git, write
  `Changes` notes and prose docs. When in doubt, delegate. Why: only the
  `alien-libgit2-*` agents get `alien-libgit2-core` / `perl-alien` force-loaded via
  `briefing.skills`; you get no briefing and would edit the build with too little context.
- **You cannot spawn subagents** (you ARE an `alien-libgit2-*` agent): the lock does not
  apply — implement, refactor, debug and test per these rules.

Behavior-relevant = anything changing what gets installed or how it is found: `alienfile`,
`share/`, `.github/workflows/`, `cpanfile`, `dist.ini`, `t/`, and the POD stating the
version floor. Prose and `Changes` notes are not.

## Project hazards — why this file is worth loading

- **A green CI job can be testing the wrong path.** Without `ALIEN_INSTALL_TYPE`, a failed
  probe falls through to a share build and the job passes as "system" — which is exactly
  what happened here with apt's below-floor libgit2-dev. Every job pins `install-type:`;
  pin it for any job you add.
- **Local `dzil test` proves one path at most.** On a machine with libgit2 it never enters
  the share build; on Debian it never enters the probe. Anything touching the build runs
  both: `env ALIEN_INSTALL_TYPE=share dzil test` **and** `…=system dzil test`.
- **No Debian release meets the 1.9.3 floor** (bookworm 1.5.1, trixie 1.9.0). A failing
  probe there is the designed outcome — never lower `minimum_version` to make it pass.
  The reason (ssh hang, libgit2 PR #7165) is in skill `alien-libgit2-core`.
- **`.claude/` is git-ignored except for a whitelist** in `.gitignore`. A new directory
  under it stays invisible to git until whitelisted — verify with `git status --short`.
- **Skills under `.claude/skills/` are hardlinks** to `~/dev/skills/…`. Never `Edit`/
  `Write` one — rewrite in place (`cat > path <<'EOF'`), or every other repo silently
  keeps the old content. `manage-skills check` verifies, `manage-skills sync` repairs.

## Coordination — karr board (always in scope)

Ticket coordination is the orchestrating agent's job, so `karr` is always in scope — don't
invoke the `kanban-issues-karr-cli` skill first, just use it. Git-native kanban, state in
`refs/karr/*` of this repo: `karr board` / `karr list --compact` to see open work,
`karr create "Title" --priority high`, `karr move ID in-progress --claim NAME`,
`karr handoff ID --claim NAME`. Full surface: that skill.

Work owned by `Git::Libgit2` or `Git::Native` becomes a ticket on that repo's board —
never a direct edit there. **Serialize board mutations when fanning out**: implementation
may run parallel, the `karr move`/`handoff`/`sync` calls run sequentially.

## Release — never without permission

`dzil build` / `dzil test` are fine anytime. `dzil release` and any CPAN upload are
STRICTLY forbidden without the maintainer's explicit go-ahead — even if a plan lists
"release" as the next step. A libgit2 version change is always its own release, and
`Git::Libgit2` / `Git::Native` get told. Pre-release audit goes through
`alien-libgit2-release-checker`.

## Public issues (GitHub) — never act without instruction

**karr** is the internal agent board, churned freely. **GitHub issues**
(`github.com/Getty/p5-alien-libgit2`) are the public tracker: real humans, published under
the maintainer's account. Never act on one on your own initiative — not even to read it —
unless the user points at a specific item.

## Perl and Alien specifics — reference, don't restate

House Perl style: skill `getty-perl-core`. Alien::Build mechanics: skill `perl-alien`.
This distribution's own facts: skill `alien-libgit2-core`. Do not duplicate them here.
