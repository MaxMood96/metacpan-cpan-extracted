# Deploying mcp-ks

One MCP server over the canonical memory/skills store, reachable from both
machines and from any other MCP-capable agent. See `SPEC.md` for what it
is and `README.md` for the module documentation.

## What runs where

```
agent (Claude Code on either machine, or any MCP client)
  │  MCP over Streamable HTTP, Bearer token
  ▼
traefik            TLS, routes ${MCP_KS_DOMAIN}
  │
  ▼
mcp-ks container  POST /mcp, GET /health
  │  SQL
  ▼
PostgreSQL          the canonical store
```

There is no shared filesystem: both machines reach the same database over
the network, which is what makes it canonical. SQLite was the other
option and was rejected — its locking over NFS is not safe with two
machines writing.

## The store

Two tables. `entries` is the named thing (`kind` + `name`, unique
together, so a memory and a skill may share a name). `revisions` is
append-only history: one row per save, holding the body and the metadata
as columns, and `entries.head_id` points at the current one.

Nothing is ever overwritten. That is deliberate — it replaces the git
history `SPEC.md` originally relied on:

| git | here |
|---|---|
| commit | a row in `revisions` |
| HEAD | `entries.head_id` |
| `git log` | `list_memory_revisions` / `list_skill_revisions` |
| `git show HEAD~1` | `get_memory(name, revision)` |
| `user.name` | `revisions.author` |

Like `user.name`, `author` is claimed, not authenticated — the token is
shared, so it records who *said* they wrote something. A client passes it
explicitly; otherwise the auth principal is used.

Frontmatter is still the wire format, since that is what agents already
write, but it is not how anything is stored: on the way in it is parsed
into columns, on the way out it is rendered back from them.

Migrations run at startup, so a fresh database and an upgraded image both
end up at the current schema with no separate deploy step. Set
`MCP_KS_NO_MIGRATE` to manage the schema out of band.

Set `MCP_KS_NO_PURGE=1` to disable the `purge_*` tools server-wide if you
want to prevent permanent deletion and enforce archive-only workflows.

## Bring it up

```bash
cp .env.dist .env
$EDITOR .env                     # token, postgres password, hostname
docker network create traefik    # if it does not exist yet
docker compose up -d --build
```

That starts Postgres alongside the app. To use a Postgres you already
run, drop the `db` service and set `POSTGRES_HOST`/`POSTGRES_PORT`.

Prereqs resolve against `https://cpan.opndev.io`, the private mirror
this ecosystem's own packages (and its plugin distributions) come from.
`docker-cpanm` turns `PERL_CPM_MIRROR` into `--mirror` by itself, so
nothing else is needed.

Check it:

```bash
curl -s https://mcp-memory.local.opndev.io/health
# {"database":"up","status":"ok"}
```

`/health` is deliberately unauthenticated — it is what traefik and the
container healthcheck poll, and it reveals nothing about the contents. It
does run a query, since a server that cannot reach Postgres is not
healthy however well it answers HTTP. Everything under `/mcp` needs the
token.

## Tools

| Tool | |
|---|---|
| `list_memories(project?)` | current revision of each memory (excludes archived) |
| `search_memories(query, project?)` | substring search over name, description and body (excludes archived) |
| `get_memory(name, revision?)` | full content, current or historical (works on archived too) |
| `save_memory(name, content, type, description?, project?, author?)` | appends a revision |
| `list_memory_revisions(name)` | history, newest first |
| `list_skills`, `get_skill`, `save_skill`, `list_skill_revisions` | the same for skills |
| `archive_memory(name, expected_revision?, author?, reason?)` | soft delete, hides from list/search |
| `restore_memory(name, author?, reason?)` | undo archive |
| `purge_memory(name, expected_revision?, author?, reason?)` | permanent deletion (can be disabled via `MCP_KS_NO_PURGE`) |
| `list_archived_memories(project?)` | list archived memories |

Search is substring matching (`ILIKE`), not `tsquery`: it is what
`SPEC.md` describes, and it keeps the returned `matches` lines exactly
the lines that matched — stemming would report hits no line contains.
Only the head of each entry is searched, so superseded wording does not
resurface. A `tsvector` index is the upgrade path if this ever gets slow.

## Resource Templates

In addition to tools, the server exposes MCP resource templates for direct
addressable reads:

| Resource Template | Description |
|---|---|
| `memory://memories/{name}` | Read current memory |
| `memory://memories/{name}/revisions/{revision}` | Read specific memory revision |
| `skill://skills/{name}` | Read current skill |
| `skill://skills/{name}/revisions/{revision}` | Read specific skill revision |
| `spec://specs/{name}` | Read current spec |
| `spec://specs/{name}/revisions/{revision}` | Read specific spec revision |

These provide a URI-based alternative to the `get_*` tools. Clients can use
`resources/list` to discover available templates, then `resources/read` to
fetch a specific resource.

## Agent tokens

Agents authenticate with a named token and have no accounts — a token is
a credential, not a login, and it grants the MCP tools and nothing else.
There is no web interface for managing them yet, so the CLI is how:

```bash
docker compose exec app ./bin/mcp-ks token add 'claude-code machine-a'
docker compose exec app ./bin/mcp-ks token list
docker compose exec app ./bin/mcp-ks token revoke 'claude-code machine-a'
```

A token is shown once, at creation. Only its SHA-256 is stored, so it
cannot be recovered — mint a new one instead. Revocation takes effect on
the next request, with no restart.

Give each machine its own, because the name is what the history records:
a save with no explicit `author` is attributed to the token that made it,
so `list_memory_revisions` shows which agent wrote what. Revoking one
machine then leaves the other working.

`MCP_KS_TOKEN` still works, as a bootstrap credential for reaching a
fresh deployment before any token exists. It writes as `bootstrap`, and
unlike a real token it cannot be revoked from the database — so drop it
from `.env` once you have minted the real ones.

## Client wiring

Both profiles get the same entry, pointing at the same server:

```json
{
  "mcpServers": {
    "memory": {
      "type": "http",
      "url": "https://mcp-memory.local.opndev.io/mcp",
      "headers": {
        "Authorization": "Bearer ${MCP_KS_TOKEN}"
      }
    }
  }
}
```

Keep the token in the environment rather than in a committed `.mcp.json`.
Give each machine the token minted for it, so the history attributes
writes correctly and one machine can be cut off without touching the
other.

Then tell the agents to prefer it. The server is authoritative; a local
memory file is only a fallback for when it cannot be reached:

> Memories and skills live on the shared MCP server (`memory`). Read with
> `list_memories`/`search_memories`/`get_memory`, write with
> `save_memory`, passing `author` so it is clear which machine wrote it.
> Search before saving so an existing entry gets a new revision instead
> of being duplicated under a new name. Only if the server is
> unreachable, write to `$CLAUDE_CONFIG_DIR/projects/.../memory/` and
> move it across afterwards.

## Running it without a container

```bash
export MCP_KS_PG='postgresql://mcp_ks:pw@127.0.0.1:5432/mcp_ks'
./bin/mcp-ks token add 'laptop'
./bin/mcp-ks daemon -l 'http://*:3000'
```

The same `MCP_KS_PG` serves the CLI and the server, so tokens can be
minted before anything is listening.

## Tests

`t/02` and `t/03` need a database and skip without one. They drop and
recreate the `public` schema, so point them at something disposable:

```bash
docker run -d --name mcp-ks-pg-test -p 15433:5432 \
  -e POSTGRES_PASSWORD=testpw -e POSTGRES_USER=mcp_ks \
  -e POSTGRES_DB=mcp_ks_test postgres:17

TEST_ONLINE='postgresql://mcp_ks:testpw@127.0.0.1:15433/mcp_ks_test' prove -l
```

## Operational notes

- **Every live token has the same rights**: read and write everything.
  Tokens separate *who* and allow revocation per machine, not what each
  may do — scopes remain a non-goal (`SPEC.md`).
- **Back up the database.** With the files gone, the Postgres volume is
  the only copy — there is no git repo to fall back on. `pg_dump` on a
  schedule.
- **Concurrent saves are safe but still last-writer-wins**: two agents
  saving the same entry produce two revisions, and the later one becomes
  the head. Nothing is lost, and the loser is still readable by revision.
- **A save with no metadata inherits it** from the current head, so
  changing only the body keeps the description, type and project.
