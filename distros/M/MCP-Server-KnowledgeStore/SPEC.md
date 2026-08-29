# Shared Memory/Skills MCP Server — Spec

## Problem

Two work profiles (two machines) currently maintain separate copies of the
same Claude memory and skills data. There's no way for other AI agents
(non-Claude-Code tools) to read or contribute to what's been learned.

## Goal

One canonical store for project memories and skills, exposed over MCP so
any agent on the network — Claude Code on either machine, or any other
MCP-capable agent — can read and write it through the same interface,
instead of each maintaining its own local copy.

## Non-goals (v1)

- No semantic/vector search (plain substring matching over name,
  description and body is enough at this scale).
- No per-agent auth *scopes*. Each agent gets its own named token, so
  access can be granted and revoked per machine, but every live token
  carries the same rights: read and write everything.
- No accounts for agents. An agent presents a credential; there is no
  user record behind it, no login and no session. (An admin interface for
  the human operator is a later version, and will not share this path.)
- No conflict resolution UI — the revision history is the audit trail;
  concurrent saves each append a revision, so the later one simply
  becomes the current version and nothing is lost.
- No migration tooling — the existing per-profile memory sets get moved
  across by hand.
- No web UI. This app is bare Mojolicious with no UI dependency at all;
  an admin interface, if built, is its own project talking to this one
  over MCP like any other agent.

## Architecture

```
Agent (Claude Code, other MCP client)
      │  MCP over Streamable HTTP
      ▼
traefik (TLS termination, routing)
      │
      ▼
MCP server (Perl/Mojolicious, container)
      │  SQL
      ▼
PostgreSQL (reached over the network by both machines)
```

Postgres rather than files on a shared mount: both machines reach one
database directly, so there is nothing to keep in sync and no shared
filesystem to depend on. SQLite was considered and rejected — its
locking over NFS is not safe with two machines writing.

## Data model

The revisioned resources use two core tables. `entries` is the named thing:
`kind` (`memory`, `skill` or `spec`) plus `name`, unique together, so
resources of different kinds may share a name. It also holds the current
`head_id` and the resource's view/usefulness counters.

`revisions` is the append-only history: one row per save, holding the body
and revision metadata as columns (`description`, `type`, `project_id`,
`author`, `created_at`). `project_id` is populated only for specs; memory
and skill project associations are entry-level tags. Saving never updates
an existing revision: it inserts a new row and moves `entries.head_id`.

Projects are normalized in `projects`. `entry_projects` associates a memory
or skill with any number of projects, while `project_agents` records which
projects an agent is tailored for. Project names are case-insensitively
unique.

Agent definitions live separately in `agents`, as opaque files overwritten
in place. They deliberately do not use the revisioned-resource model.

This is what replaces the git history the original file-based design
relied on:

| git | here |
|---|---|
| commit | a row in `revisions` |
| HEAD | `entries.head_id` |
| `git log` | `list_*_revisions` |
| `git show HEAD~1` | `get_*(name, revision)` |
| `user.name` | `revisions.author` |

## Lifecycle management

Every entry has a lifecycle: active, archived, or purged.

- **Active** (default): Visible in `list_*`, `search_*`, and `get_*`. All saves
  create or update active entries.
- **Archived**: Hidden from `list_*` and `search_*`, but still retrievable via
  `get_*` by name and visible in `list_archived_*`. All data, revision history,
  and project tags are preserved. Archiving is the recommended way to remove
  entries from normal use.
- **Purged**: Completely removed from the database including all revision history
  and project tags. Cannot be restored. `purge_*` tools perform this destructive
  operation.

Archiving supports an optional `expected_revision` check to prevent stale
operations: if provided, the operation verifies the entry's current revision
matches before proceeding. All lifecycle operations record the acting
principal, timestamp, and optional reason in the `audit_log` table.

The `purge_*` tools can be disabled server-wide by setting the
`MCP_KS_NO_PURGE` environment variable to a true value. When disabled,
all purge operations return an error, allowing deployments to enforce
archive-only workflows that preserve audit trails.

By default, `author` is the authenticated named token's principal. Save tools
also accept an explicit `author`, so a caller may override that attribution
when acting on behalf of another agent or importing existing material.

`tokens` holds the agent credentials: a name, the
SHA-256 of the token, and `created_at` / `last_used_at` / `revoked_at`.
Only the hash is stored, so a database dump yields nothing usable, and a
token is 32 random bytes — there is nothing to brute-force, which is why
a single SHA-256 is the right hash rather than a password KDF. Revoking
keeps the row and the name reserved, so a retired credential's name can
never come back on a new token.

`type` for memories: `user`, `feedback`, `project`, `reference` (as
already used), enforced by a CHECK constraint and by the tool schema.
Skills are freeform guidance docs and carry no type.

Frontmatter stays the wire format for revisioned content, since that is what
agents already write, but it is not how the revision metadata is stored: on
the way in supported fields are parsed into columns or project tags, and on
the way out stored revision fields are rendered back into frontmatter.
Memory and skill project tags are returned in structured `list_*`/`search_*`
results rather than rendered as a single frontmatter project. Agent files
are the exception: they are stored and returned verbatim. There is no index
file — `list_*` is a query.

## MCP tools exposed

| Tool | Description |
|---|---|
| `list_memories(project?)` | Current revision of each memory |
| `search_memories(query, project?)` | Substring search over name, description and body |
| `get_memory(name, revision?)` | Full content, current or historical |
| `save_memory(name, content, type, description?, project?, author?)` | Append a revision |
| `list_memory_revisions(name)` | History, newest first |
| `list_skills(project?)` | Current revision of each skill |
| `get_skill(name, revision?)` | Full content, current or historical |
| `save_skill(name, content, description?, project?, author?)` | Append a revision |
| `list_skill_revisions(name)` | History, newest first |
| `list_specs(project?)` | Current revision of each spec |
| `get_spec(name, revision?)` | Full content, current or historical |
| `save_spec(name, content, project, description?, author?)` | Append a revision |
| `list_spec_revisions(name)` | History, newest first |
| `mark_memory_useful(name)` / `mark_skill_useful(name)` / `mark_spec_useful(name)` | Increment `useful_count`, a signal separate from view count |
| `list_projects()` | Distinct project names in use across specs, memory/skill tags and agent tags |
| `list_agents(project?)` | Agent definitions - global, optionally filtered to those tagged for a project |
| `get_agent(name)` | Full file content, verbatim |
| `save_agent(name, content, author?)` | Overwrite in place |
| `tag_memory(name, project)` / `tag_skill(name, project)` / `tag_agent(name, project)` | Add a project tag, additive |
| `untag_memory(name, project)` / `untag_skill(name, project)` / `untag_agent(name, project)` | Remove one project tag |
| `archive_memory(name, expected_revision?, author?, reason?)` / `archive_skill(...)` / `archive_spec(...)` | Soft delete: hide from normal operations, keep all data and revision history |
| `restore_memory(name, author?, reason?)` / `restore_skill(...)` / `restore_spec(...)` | Undo archive, make visible again |
| `purge_memory(name, expected_revision?, author?, reason?)` / `purge_skill(...)` / `purge_spec(...)` | Permanent deletion of entry and ALL revision history |
| `list_archived_memories(project?)` / `list_archived_skills(...)` / `list_archived_specs(...)` | List archived entries, same filtering as list |

`description` is on the save tools because frontmatter carries one and
there would otherwise be no way to set it. `author` records which agent
or machine made the revision.

A spec is a project's write-up - what the project is meant to do, kept
in the same append-only shape as a memory or skill so it gets revision
history for free. Unlike memory and skill, `project` is required on
`save_spec` and stays a single value on the revision: a spec document
belongs to exactly one project by definition, and a spec with no project
would have nothing to be read against.

Memory and skill are different: the same memory or skill can matter to
more than one project (or none), so `project` is **not** a column on
their revisions - it is a tag on the entry, independent of revision
history, recorded in `entry_projects` (many-to-many). `save_memory` /
`save_skill`'s `project` argument, when given, adds a tag; it does not
replace existing ones. `tag_memory`/`untag_memory` (and the `skill`
equivalents) manage tags directly without a save. `list_memories(project)`
/ `search_memories(query, project)` (and `list_skills`) filter by that
tag; a spec's `project` filter still reads the single revision column.

Every `get_*` call bumps that entry's `view_count` and `last_viewed_at`
(a `list_*`/`search_*` call does not, since it never fetches a single
entry's full content); `mark_*_useful` is a separate, explicit signal an
agent gives after actually finding the content useful, not merely
reading it.

Agent definitions (`.claude/agents/*.md`) are a fourth, deliberately
different case, stored in their own `agents` table rather than
entries/revisions: their frontmatter carries fields (`tools`, `model`,
...) this store has no reason to parse, so the whole file is kept as one
opaque blob, overwritten in place - no revision history, no view/useful
counters, no frontmatter splitting. Agents are global: there is one
"analyse", not a per-project copy, so `name` alone is the key. Which
projects an agent is *tailored for* is the same many-to-many tagging
idea as memory/skill, recorded in `project_agents` and managed by
`tag_agent`/`untag_agent`; `list_agents(project)` filters by it.

Reading an agent back over MCP does not make it usable - Claude Code
resolves `subagent_type` from local files before any tool call happens,
so using a stored agent still means syncing it to a local
`.claude/agents/<name>.md` first; there is no live-fetch path the way
there is for skills.

All tools operate on the single shared store — no per-project namespacing
in v1 beyond an optional `project` filter on list/search.

## Memory retrieval interface

MCP tool arguments are JSON objects. Memory retrieval is split by intent and
cardinality rather than by project-specific endpoints:

- `list_memories({project?})` returns summaries for all memories, optionally
  restricted to memories tagged with one project.
- `search_memories({query, project?})` searches memory names, descriptions
  and current bodies, optionally restricted to one project.
- `get_memory({name, revision?})` retrieves the full content of exactly one
  known memory, at its current or a historical revision.

For example, `search_memories({query: "icecream"})` searches globally, while
`search_memories({query: "icecream", project: "today"})` returns only matching
memories associated with `today`. `list_memories({project: "today"})` lists
every memory associated with that project. Any collection operation may
return zero, one or many entries; exact retrieval remains singular and uses
the memory's `name` as its identifier.

A memory is independently identified and may be associated with multiple
projects. Project membership is therefore many-to-many: a project is a
retrieval and organization scope, not part of a memory's identity. A separate
`get_project_memories` tool is unnecessary because the `project` argument on
the collection tools expresses that filter directly.

Filtered retrieval is exposed as tools because it executes queries over
collections. In addition to tools, exact addressable reads are also available
through MCP resource templates:

| Resource Template | Description |
|---|---|
| `memory://memories/{name}` | Read current revision of a memory |
| `memory://memories/{name}/revisions/{revision}` | Read a specific memory revision |
| `skill://skills/{name}` | Read current revision of a skill |
| `skill://skills/{name}/revisions/{revision}` | Read a specific skill revision |
| `spec://specs/{name}` | Read current revision of a spec |
| `spec://specs/{name}/revisions/{revision}` | Read a specific spec revision |

These resource templates provide an alternative to the `get_*` tools, allowing
clients to read resources directly via URI. The templates use the same
underlying `get_*` functionality, so they respect the same access controls and
return the same content. Unlike tools, resource templates are read-only.

## Server behavior

- Reads are live — no caching — so a change made by any caller, or
  directly in SQL, is visible to the next request.
- Every revisioned `save_*` call inserts a revision inside a transaction and
  moves the entry's head to it. Omitted descriptions inherit from the current
  head. A spec may inherit its single project at the store layer, although
  the MCP `save_spec` schema requires callers to provide one. Memory's MCP
  schema requires `type` on every save. Memory and skill project arguments
  add entry-level tags and do not replace or inherit revision metadata.
- Only the current revision is listed and searched, so superseded wording
  does not resurface; older revisions stay readable by number.
- Search is substring matching (`ILIKE`), not `tsquery`, so the returned
  matching lines are exactly the lines that matched. A `tsvector` index is
  the upgrade path if it ever gets slow.
- Names are held to a pattern (`[A-Za-z0-9][A-Za-z0-9_:-]*`) that supports
  both slug-style identifiers (e.g., `my-memory-name`) and namespace-style
  identifiers (e.g., `My::Module::Name` or `mcp:tools:repo`). This pattern is
  enforced in Perl, in the tool schemas, and by a CHECK constraint in the
  database.
- Migrations run at startup, so a fresh database and an upgraded image
  both land on the current schema with no separate deploy step.
- Every request carries a bearer token, looked up by hash against
  `tokens`. The token's name becomes the request principal, and thereby
  the default `author` of anything it writes — so the history shows which
  agent said what, without any agent having an account.
- `MCP_KS_TOKEN` remains as a bootstrap credential for reaching a fresh
  deployment before a token has been minted. It cannot be revoked from
  the database, so it is meant to be dropped afterwards.
- `/health` is unauthenticated and runs a query, since a server that
  cannot reach Postgres is not healthy however well it answers HTTP.

## Transport & deployment

- Streamable HTTP transport (not stdio — must be reachable from both
  machines and non-local agents), via the `MCP` distribution's
  `to_action`.
- Exposed via a reverse proxy at an internal hostname
  (e.g. `mcp-memory.local.opndev.io`), with TLS terminated by the proxy.
- Runs as a small container against the same private CPAN mirror this
  ecosystem already uses. The deployable `srv-memory` bundle installs the
  core server and all resource plugins. Runtime configuration supplies the
  database credentials and may supply a bootstrap bearer token for initial
  setup; named database tokens are the normal long-lived credentials. The
  Compose file in this source tree is an example and is not the definition
  of the live deployment. See `DEPLOY.md`.

## Client wiring

- Add the server to both profiles' MCP client config (`.mcp.json` or
  equivalent) pointing at the HTTPS URL with the bearer token.
- Update CLAUDE.md instructions to call the MCP tools instead of writing
  to `$CLAUDE_CONFIG_DIR/.../memory/` directly. The server is
  authoritative; writing a local file is only a fallback for when it
  cannot be reached.

## Resolved

- **No index file.** The directory scan the original spec was leaning
  towards became a query; `MEMORY.md` does not exist any more, so there
  is nothing to drift.
- **No import tool.** The existing per-profile sets get moved across by
  hand, once.

## Still open

- Back up the database. With the files gone, the Postgres volume is the
  only copy — there is no git repo to fall back on.
- An admin interface for the operator: managing tokens and configuration
  from a browser rather than the CLI. Deliberately a later version, its
  own project talking to this one over MCP, and a separate
  authentication path from the agents' — a human logs in, an agent
  presents a token, and neither grants the other's access.
