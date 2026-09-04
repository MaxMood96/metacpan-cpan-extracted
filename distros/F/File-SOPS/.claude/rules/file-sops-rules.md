# File::SOPS House Rules

Apply to every task in this repository unless explicitly overridden. Bias: caution over
speed on non-trivial work; use judgment on trivial tasks. Loaded automatically at launch
(same priority as `CLAUDE.md`). Subagents get their conventions from the skills
force-loaded via `briefing.skills` — this file is for the orchestrating agent.

## Engineering discipline

1. **Think before coding** — State assumptions. When uncertain, ask rather than guess.
   Present alternatives when ambiguous. Push back when a simpler approach exists. Stop
   when confused; name what's unclear.
2. **Simplicity first** — Minimum code that solves the problem. Nothing speculative.
3. **Surgical changes** — Touch only what you must. Don't "improve" adjacent code,
   comments, or formatting. Match existing style.
4. **Read before you write** — Before new code, read the callers and the twin: the
   value→bytes conversion and the type ladder each exist in more than one place, and
   changing one without the other is this distribution's signature bug.
5. **Tests verify intent, not just behavior** — Reproduce a bug before fixing it; leave
   a regression test behind. A test that can't fail when the wire format changes is not
   a test of this distribution.
6. **Match the codebase's conventions, even if you disagree** — Conformance > taste.
   Surface a harmful convention; don't fork silently.
7. **Fail loud** — "Done" is wrong if anything was skipped silently. "Tests pass" is
   wrong if any were skipped. Surface uncertainty, don't hide it.
8. **A red test is a claim before it is a failure** — Before changing code to turn a
   test green, say what the test asserts and whether your fix keeps that claim or
   replaces it. If the claim is wrong, fix the claim and say so.

## Delegation

Depends on whether the Agent/Task tool is available to you.

- **You can spawn subagents** (orchestrating main agent): Do NOT touch behavior-relevant
  code yourself — delegate. Your lane: coordinate, inspect, plan, review diffs, run
  tests, manage git, edit non-behavioral docs. Why: only the `file-sops-*` agents get
  their skills force-loaded via `briefing.skills`; you get no briefing and would touch
  format-critical internals with too little context.

  | Task | Agent |
  |---|---|
  | Value types, encoding, AES-GCM, MAC/AAD, backends | `file-sops-wire` |
  | Public API, guards, error behaviour, rule policy | `file-sops-api` |
  | Parsers, emitters, quoting, the order-preserving reparse | `file-sops-format` |
  | Write/extend tests, reproduce interop bugs | `file-sops-test-writer` |
  | Pre-release audit | `file-sops-release-checker` |

  Pick the lane by what the change *moves*, not by which file it starts in: a two-line
  edit in `Format/YAML.pm` that changes what gets hashed belongs to `file-sops-wire`.
  When a ticket spans lanes, run them in sequence and let each report what it handed
  on — parallel workers in the same file overwrite each other, since only isolated
  worktrees give them separate copies.

- **You cannot spawn subagents** (you ARE a `file-sops-*` agent): The delegation lock
  does not apply — implement, refactor, debug, and test per these rules.

Behavior-relevant = anything under `lib/`, the tests, and any change to the encrypted
wire format, MAC computation, AAD derivation, type detection, or serialization. Prose
docs, `README.md` and `Changes` wording are not.

## Interop is the product — a green suite is not a proof

This distribution's entire claim is byte compatibility with the Go `sops`
implementation. `t/04-interop.t` is the only test that checks it, and it `skip_all`s
unless a `sops` binary exists at `/tmp/sops` or `$SOPS_BIN`. Without it the suite
reports `All tests successful` having skipped ~500 lines of compatibility assertions.

Never report a green suite as evidence for a format-touching change. State which of the
two ran:

```bash
prove -lr t/                                     # unit only, if no binary
SOPS_BIN=/path/to/sops prove -lv t/04-interop.t  # the actual proof
```

Self-consistency is the failure mode, not the safety net: this library encrypting and
decrypting its own output proves nothing about what `sops` will accept.

## Cryptographic code — no drive-by changes

Nonce sizes, tag handling, AAD construction, key derivation and the MAC are specified by
the reference implementation, not chosen here. Anything that looks wrong (a 32-byte GCM
nonce, `sort keys` in one MAC path and document order in the other) is far more likely
to be a deliberate Go-compatibility choice than a bug — verify against the reference
before "fixing" it, and never weaken a check to make a test pass. Secrets, age keys and
plaintext values never land in logs, commit messages or ticket bodies.

## Coordination — karr board (always in scope)

Ticket coordination is the orchestrating agent's job, so `karr` is always in scope —
don't invoke the skill first, just use it. Board state lives in `refs/karr/*` in this
repo.

- `karr list --compact` / `karr board` — open work · `karr show ID` — detail
- `karr create "Title" --priority high --tags a,b --body '…'` — new ticket
- `karr edit ID -a "note"` · `--claim NAME` · `--block "why"` — update
- `karr move ID in-progress --claim NAME` — start · `karr handoff ID --claim NAME --note "…"` — to review

Full command surface: skill `kanban-issues-karr-cli`.

## Release — never without permission

`dzil build` / `dzil test` / `prove -lr t/` are fine anytime. `dzil release` and any
CPAN upload are STRICTLY forbidden without the maintainer's explicit go-ahead — even if
a plan lists "release" as the next step. For anything heading toward release: stop and
ask. After a release the `$VERSION` bump is a separate, deliberate commit.

## GitHub issues — never act without instruction

`karr` is the internal agent board, churned freely. GitHub issues on
`Getty/p5-file-sops` are the **public tracker**: real people's reports, written under
the maintainer's account. Never act on one on your own initiative — not even to read
it. No listing, viewing, commenting, closing or creating unless the user explicitly says
to handle a specific issue.

## Perl specifics — reference, don't restate

Module loading, Moo patterns, cpanfile pinning for Getty-authored dependencies, POD
conventions and house style live in skills `getty-perl-core`, `getty-perl-moo` and
`getty-perl-release-author-getty` (force-loaded for `file-sops-*` agents). The SOPS wire
format and its invariants live in skill `file-sops-core`. Do not duplicate them here.
