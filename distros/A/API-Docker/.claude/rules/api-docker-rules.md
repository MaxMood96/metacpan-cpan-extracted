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
   handling reaches every module in `lib/` and the mock harness at once.
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
  | The generated type model, the `API::Docker::Type` DSL, the drift checker, `spec/` | `api-docker-type-writer` |
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

## Parallel fan-out — isolate the working tree

Subagents share one working tree with the orchestrator and with each other. A global git
command in one reaches all of them, so:

- **A subagent never mutates git** — no `stash`, `reset`, `checkout -- <path>`, `clean`,
  `add` or `commit`. The orchestrator owns git and commits. Say so in every subagent
  prompt, but do not rely on the prompt alone: a subagent's `git stash`/`reset`/`checkout`
  has thrown away another agent's uncommitted work three times (k111) even when the prompt
  forbade it.
- **When two or more code-touching agents run at once, isolate them.** Launch each with
  `isolation: "worktree"` so a stray git command in one cannot reach another's tree, or run
  them sequentially in the shared tree. Never fan out parallel code-touching agents into the
  same working tree without isolation.
- **A worktree may branch from a stale base.** Integrate its result by the diff
  (`git diff <merge-base> <branch> -- <files>` piped to `git apply`, or a cherry-pick),
  never by `git checkout <branch> -- <file>` for a file the main tree has since changed —
  that reverts the main tree to the stale copy. Check the merge-base against what main
  touched first.
- **Commit a verified-green checkpoint before the next mutating fan-out.** A committed HEAD
  is immune to a later stray `stash`/`reset`; uncommitted work is not.

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

- **Which engine is there is a fact about the machine, not about this file.** Before
  any live run, check which sockets exist (`/var/run/docker.sock`,
  `$XDG_RUNTIME_DIR/podman/podman.sock`) and what each announces on `GET /version` --
  `Platform.Name`, `ApiVersion`, `MinAPIVersion`. `check_live_access` answers a missing
  socket with `skip_all`, so a live run pointed at a socket that is not there reports
  success while testing nothing: read the skip line. The `/v1.XX/` in a hand-written
  curl is what the request asked for, not what the engine is. A measurement names the
  engine and the version it was taken on, or it is not a measurement.
- **Live write tests mutate the real engine.** `API_DOCKER_TEST_WRITE=1` creates and
  removes actual containers, images, networks and volumes; cleanup runs in an `END`
  block, so an interrupted run leaves them behind. Run only when the task is about live
  behavior.
- **`prune` destroys, and `dangling => 0` destroys MORE, not less.** `POST
  /images/prune` with `filters => { dangling => ['false'] }` removes every
  unused *tagged* image on the engine, locally built ones included, and they
  are not recoverable. It reads like a narrowing filter and is the opposite.
  This has already cost a locally built image, during what its caller
  believed was a read-only probe. **No `prune` of any
  kind -- images, containers, networks, volumes, build cache -- and no
  `rm -a` or `system reset`, on either engine, ever, unless the user names
  the command.** Probing what an endpoint answers is not a reason: measure
  it against something you created yourself.
- **`images->push` publishes.** With credentials it writes to a real registry under the
  maintainer's account. Never run it — nor any test that does — without explicit
  instruction.
- **Streaming endpoints block until the daemon closes, unless given a callback.**
  `_request` still buffers a whole response by default, so `system->events` or
  `containers->stats` without a bound and without `on_event`/`on_frame`/`on_chunk` never
  returns. Bound the window, pass a callback, or wrap a manual probe in `timeout` — a
  callback still needs `$stop->()` called from somewhere, or it runs until the daemon
  closes the connection on its own.
- **`../p5-dist-zilla-plugin-docker-api` consumes this API.** A public signature or
  return-shape change is a cross-repo change: verify that repo, or file a ticket on its
  board before landing.
- **`[@Author::GETTY]` gathers through `Git::GatherDir`, which sees only tracked
  files.** A new `.pm`, test file or fixture is invisible to `dzil build`/`dzil test`
  until it is `git add`-ed — while `prove -lr t/` stays green the whole time, because it
  reads `lib/` and `t/` directly rather than through the gathered file list. A `dzil
  build` failure that looks like a missing module, or a passing `prove` next to a
  failing `dzil test`, is this before anything else: check `git status` for an untracked
  file first.

## Perl specifics — reference, don't restate

Module loading, `$VERSION`, cpanfile pinning and house style: skills `getty-perl-core`,
`getty-perl-moo`. `[@Author::GETTY]`, POD weaving, `{{$NEXT}}`: skill
`getty-perl-release-author-getty`. dist.ini mechanics: `perl-release-dist-ini`. Commit
messages: `getty-git-commit-style`. Architecture and transport invariants:
`api-docker-core`. What the daemon itself does — wire formats, response shapes, filters,
registry auth: `docker-engine-api` (briefed only into the engine-worker and the
test-writer). Don't duplicate any of it here.
