# CLAUDE.md

Repo-specific guidance for Claude Code working on `API::Docker`.

## The 12 Rules

These are the operating rules for this repo. They inherit from the global
and workspace `CLAUDE.md` — what's listed here is the authoritative set
for this distribution.

1. **Use `mcp__serper__google_search` or `mcp__firecrawl__firecrawl_search`**
   over `WebSearch` for any web lookup.

2. **Use `mcp__firecrawl__firecrawl_scrape`** over `WebFetch` for fetching
   page content.

3. **Use `context7` for library docs** (CPAN, npm, etc.) — *except* this
   distribution itself. For `API::Docker` always read the local source
   under `lib/`, never context7.

4. **Untracked files that are not in `.gitignore` belong in the commit.**
   `.gitignore` is the source of truth. Only obvious secrets
   (`.env`, credentials) are excluded — and even then warn, don't silently
   drop them.

5. **Auto-Memory is for personal/user preferences only.** Project
   conventions belong in this `CLAUDE.md` or in a skill, never in
   auto-memory.

6. **Load the `getty-perl-core` skill before editing any Perl** in this
   workspace. It encodes Getty's house rules; the rules below are the
   TL;DR. The `api-docker-*` agents get it force-loaded — see
   [Delegation](#delegation).

7. **`use Module;` to load modules.** Only use `require` when there's a
   real runtime reason (lazy plugin loading, optional deps), not just to
   defer cost.

8. **`->instance` for `MooX::Singleton` / `MooseX::Singleton` classes.**
   `->new` for everything else.

9. **Never copy `$VERSION` from a Getty-authored repo into a cpanfile.**
   The repo version is the *next* unreleased version. Check
   `cpanm --info` for the actual released version when pinning.

10. **Pin every Getty-authored dependency** to its latest released CPAN
    version in `cpanfile`.

11. **The version in `lib/API/Docker.pm` is the NEXT release.** What's
    currently on CPAN is the previous tag. `dzil release` bumps the
    version automatically — never bump it by hand before a release. The
    same literal is repeated in all twelve `lib/**/*.pm` files and must
    stay in sync.

12. **`{{$NEXT}}` in `Changes` is the placeholder for the upcoming
    release.** Add entries under it as you change behavior; `dzil
    release` replaces it with the version + timestamp.

## What this distribution is

A pure-Perl client for the Docker Engine API. No LWP, no shell-outs —
HTTP/1.1 (incl. chunked) is spoken directly over the daemon's Unix
socket (default) or a TCP endpoint. Any engine serving that API works;
Podman needs nothing but `DOCKER_HOST`.

The synchronous `_request` core lives in
`API::Docker::Role::HTTP`; resource-specific API methods live in
`API::Docker::API::*`. Entity wrappers (`API::Docker::Container`,
`API::Docker::Image`, ...) hang off the resource APIs.

Architecture, transport invariants, the streaming and `X-Registry-Auth`
details, and the mock harness are in skill `api-docker-core` — that is
the source of truth, not this file.

## Layout

```
lib/API/Docker.pm                       # main client, version negotiation
lib/API/Docker/Role/HTTP.pm             # HTTP/1.1 transport (unix:// + tcp://)
lib/API/Docker/API/System.pm            # /version, /info, /_ping
lib/API/Docker/API/Containers.pm        # container endpoints
lib/API/Docker/API/Images.pm            # image endpoints (build, pull, push, ...)
lib/API/Docker/API/Networks.pm          # network endpoints
lib/API/Docker/API/Volumes.pm           # volume endpoints
lib/API/Docker/API/Exec.pm              # exec endpoints
lib/API/Docker/{Container,Image,Network,Volume}.pm  # entity classes
t/                                      # tests (prove -lr t/)
t/lib/Test/API/Docker/Mock.pm           # fixture-driven mock helper
t/fixtures/*.json                       # captured daemon responses
.claude/agents/                         # the api-docker-* subagents
.claude/rules/api-docker-rules.md       # house rules, auto-loaded every turn
.claude/skills/                         # briefed skills (hardlinked + owned)
```

## Build and test

```bash
prove -lr t/            # canonical — recursive; plain `prove -l t/` skips subdirs
prove -lv t/images.t    # single test
dzil build              # build the dist
dzil test               # full suite incl. generated xt/
cpanm --installdeps .   # install deps from cpanfile
```

By default tests are fixture-driven — no daemon, no network, and it stays
that way. For the read-only live paths set `API_DOCKER_TEST_HOST`; add
`API_DOCKER_TEST_WRITE=1` for the mutating ones (they create and remove
real containers, images and volumes).

**On this machine that host is Podman, not Docker.**
`/var/run/docker.sock` does not exist here, and a missing socket makes the
suite `skip_all` — a live run pointed at the default reports success while
testing nothing:

```bash
API_DOCKER_TEST_HOST=unix:///run/user/1000/podman/podman.sock prove -lr t/
```

That run is currently not green: `t/system.t`'s `events` subtest asserts a
shape a real daemon does not return for an empty window. It is on the board,
not a new finding.

## Delegation

Don't touch behavior-relevant code yourself — hand it to the right agent.
The principle, the lanes and the repo's hazards are in
`.claude/rules/api-docker-rules.md`.

| Task | Agent |
|---|---|
| What the daemon does or expects — endpoints, wire formats, filters, registry auth | `api-docker-engine-worker` |
| The Perl side — Moo, transport internals, entities, refactoring, cpanfile | `api-docker-worker` (default) |
| Write/extend tests, add fixtures | `api-docker-test-writer` |
| Pre-release audit | `api-docker-release-checker` |
| POD and README | `api-docker-doc-writer` |

The two workers split by question, not by file. Only `api-docker-engine-worker`
is briefed with `docker-engine-api`, the shared Engine API reference.

The agents carry their skills via `briefing.skills` (see `.claude/agents/`);
the main agent delegates rather than loading them. Skill sources live under
`.claude/skills/` — `api-docker-core` is owned here, the rest are hardlinks
managed with `manage-skills` (`docker-engine-api` lives in the shared library and
is reused by `../p5-dist-zilla-plugin-docker-api`).

Ticket coordination runs on the repo's `karr` board (`karr board`).

## When changing behavior

- Add a `Changes` entry under `{{$NEXT}}`, and say what was measured.
- Update the POD on the affected class. POD lives next to the code
  (`=method`, `=attr`, `=head1 SYNOPSIS` ...) and is woven by the
  `@Author::GETTY` bundle.
- If you change a public method signature or a return shape, check that
  callers in the workspace (notably `../p5-dist-zilla-plugin-docker-api`)
  still build and test green.
