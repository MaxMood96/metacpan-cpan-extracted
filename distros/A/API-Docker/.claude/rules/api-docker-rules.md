# API-Docker House Rules

Apply to every task in this distribution unless explicitly overridden. Bias: caution over
speed on non-trivial work; use judgment on trivial tasks. Loaded automatically at launch
(same priority as `CLAUDE.md`). Subagents get their discipline from the skills
force-loaded via `briefing.skills` — this file is for the orchestrating agent.

## Engineering discipline

1. **Think before coding** — state assumptions; when uncertain, ask rather than guess.
   Push back when a simpler approach exists.
2. **Simplicity first** — minimum code that solves the problem. Nothing speculative.
3. **Surgical changes** — touch only what you must. Match existing style.
4. **Goal-driven execution** — define success criteria, loop until verified.
5. **Surface conflicts, don't average them** — pick one (more recent / more tested), flag
   the other for cleanup. Don't blend.
6. **Read before you write** — `Role::HTTP` is the single seam every resource API and
   entity class hangs off. A change to `_request`'s options, return shape or error
   handling reaches all twelve modules and the mock harness at once.
7. **Tests verify intent, not just behavior** — a test that can't fail when the logic
   changes is wrong, and a helper that normalises its input before asserting is that
   test. Reproduce a bug before fixing it; leave the regression behind.
8. **Checkpoint after every significant step** — summarize: done / verified / left.
9. **Match conventions** — conformance > taste. Surface a harmful convention; don't fork
   silently.
10. **Fail loud** — "Done" is wrong if anything was skipped. "Tests pass" is wrong if any
    were skipped — and in this repo a skip is the default failure mode, see below.
11. **A red test is a claim before it is a failure** — before changing code to turn a
    test green, say what the test asserts and whether your fix keeps that claim or
    replaces it. If the claim is wrong, fix the claim and say so.

## Delegation

This rule depends on whether the Agent/Task tool is available to you.

- **You can spawn subagents** (orchestrating main agent): Do NOT touch behavior-relevant
  code yourself — delegate. Your lane: coordinate, inspect, plan, review diffs, run
  tests, manage git, edit non-behavioral docs. When in doubt, delegate. Why: only the
  `api-docker-*` agents get their skills force-loaded via `briefing.skills`; you get no
  briefing and would touch internals with too little context.

  | Task | Agent |
  |---|---|
  | Anything turning on what the daemon does or expects — endpoints, wire formats, filters, registry auth, version gating | `api-docker-engine-worker` |
  | The Perl side — Moo, transport internals, entity classes, refactoring, cpanfile | `api-docker-worker` (default) |
  | Write/extend tests, add fixtures | `api-docker-test-writer` |
  | Pre-release audit | `api-docker-release-checker` |
  | POD and README | `api-docker-doc-writer` |

  The two workers split by *question*, not by file: "what does the engine answer here?"
  is the engine-worker's, "how is this distribution built?" is the plain worker's. Only
  the engine-worker carries the Engine API reference — the other one guessing at daemon
  behavior is how a wrong assumption gets cemented.

- **You cannot spawn subagents** (you ARE an `api-docker-*` agent): the delegation lock
  does not apply to you — implement, refactor, debug, and test per these rules.

Behavior-relevant = the HTTP transport and everything it returns, the resource API method
surface, entity wrappers, request/response encoding, error handling, `cpanfile`, and
tests. Pure prose docs and `Changes` notes are not.

## Coordination — karr board (always in scope)

Ticket coordination is the orchestrating agent's job, so `karr` is always in scope —
don't invoke the `kanban-issues-karr-cli` skill first, just use it. Git-native kanban;
state lives in `refs/karr/*`; one board, this repo. Day-to-day: `karr list --compact` /
`karr board` for open work; `karr show ID` for detail; `karr create/edit/move/handoff`
for the usual flow; mutating commands auto-sync. Use it for drift to reconcile and
follow-up work that must not block the current change. Full surface: skill
`kanban-issues-karr-cli`.

**Serialize board mutations when fanning out.** Keep implementation work parallel if you
like, but collect results and loop `karr move`/`handoff`/`sync` sequentially — N landing
at once is a resource event, not a cheap command.

## Release — never without permission

`dzil build`, `dzil test` and `prove -lr t/` are fine anytime. `dzil release` and any
CPAN upload are STRICTLY forbidden without the maintainer's explicit go-ahead — even if
`Changes` or a plan names "release" as the next step. `[@Author::GETTY]` bumps `$VERSION`
across all of `lib/` and tags on release; for anything heading toward release: stop and
ask.

## Public issues — never act without instruction

Two trackers, two universes. **karr** is the internal agent work board, churned freely.
**GitHub issues on `Getty/p5-api-docker`** and CPAN RT carry real humans' reports under
the maintainer's name. **Never act on a public issue on your own initiative — not even to
read it.** No listing, viewing, commenting, editing, closing or creating unless the user
names a specific item to handle.

## API-Docker-specific hazards

- **There is no Docker on this machine — only rootless Podman.**
  `unix:///var/run/docker.sock` does not exist here, and `check_live_access` answers a
  missing socket with `skip_all`. A live run pointed at the default therefore reports
  success while testing nothing. The real endpoint is
  `API_DOCKER_TEST_HOST=unix:///run/user/1000/podman/podman.sock` (announces API 1.41).
- **The suite is not green against a live daemon.** `t/system.t`'s `events` subtest
  asserts `ref eq 'ARRAY'` outside its `is_live()` guard; a real daemon with no events in
  the requested window returns an empty body, `_request` returns undef, and the test
  fails. It is ticketed — do not rediscover it as a new finding and do not fix it
  opportunistically.
- **`containers->logs` hands frame headers to the caller.** A container created without
  a TTY produces an 8-byte-framed stream (`01 00 00 00 00 00 00 04` + payload, stream
  type in byte 0, big-endian length in bytes 4-7) and the method returns it undecoded;
  with a TTY the stream is raw and looks correct, so hand-testing interactively hides it.
  `exec->start` shares the problem and there is no `attach` at all. Ticketed — it is a
  public return-shape change, not a passing fix.
- **Live write tests mutate the real engine.** `API_DOCKER_TEST_WRITE=1` creates and
  removes actual containers, images, networks and volumes; cleanup runs in an `END`
  block, so an interrupted run leaves them behind. Run only when the task is about live
  behavior.
- **`images->push` publishes.** With credentials it writes to a real registry under the
  maintainer's account. Never run it — nor any test that does — without explicit
  instruction.
- **Streaming endpoints block until the daemon closes.** `_request` buffers whole
  responses, so `system->events` or `containers->stats` without a bound never returns.
  Always bound the window, and wrap manual probes in `timeout`.
- **`tls` and `cert_path` are attributes with no implementation.** `Role::HTTP` never
  reads them; `tcp://` is always plaintext. Wiring TLS is new work with an ADR-grade
  decision behind it, not a repair.
- **`../p5-dist-zilla-plugin-docker-api` consumes this API.** A public signature or
  return-shape change is a cross-repo change: verify that repo, or file a ticket on its
  board before landing.

## Perl specifics — reference, don't restate

Module loading, `$VERSION`, cpanfile pinning and house style: skills `getty-perl-core`,
`getty-perl-moo`. `[@Author::GETTY]`, POD weaving, `{{$NEXT}}`: skill
`getty-perl-release-author-getty`. dist.ini mechanics: `perl-release-dist-ini`. Commit
messages: `getty-git-commit-style`. Architecture and transport invariants:
`api-docker-core`. What the daemon itself does — wire formats, response shapes, filters,
registry auth: `docker-engine-api` (briefed only into the engine-worker and the
test-writer). Don't duplicate any of it here.
