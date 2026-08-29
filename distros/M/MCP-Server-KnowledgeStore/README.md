# DESCRIPTION

A [Mojolicious](https://metacpan.org/pod/Mojolicious) application exposing one shared memory/skills store over
MCP, so every agent on the network reads and writes the same data instead
of keeping its own copy. See `SPEC.md` for the problem it solves.

Entries live in Postgres and are append-only: each save adds a revision
rather than replacing one, so the history `SPEC.md` expected from git
survives the move into the database.

Callers are agents, authenticated by a named token (see
[MCP::Server::KnowledgeStore::Command::token](https://metacpan.org/pod/MCP%3A%3AServer%3A%3AKnowledgeStore%3A%3ACommand%3A%3Atoken)) and nothing more - no accounts, no
sessions. A token's name is recorded as the author of everything it
writes.

This is a bare [Mojolicious](https://metacpan.org/pod/Mojolicious) application - no UI, no templates. An
admin interface over the same store, if one gets built, is a separate
project talking to this one over MCP like any other agent, not
something bolted onto this app's base class.

# SYNOPSIS

    MCP_KS_PG=postgresql://mcp_ks@db/mcp_ks \
    MCP_KS_TOKEN=secret \
      ./bin/mcp-ks daemon -l 'http://*:3000'

    # then, from any MCP client
    https://mcp-memory.internal.lan/mcp

# CONFIGURATION

Environment variables win over `mcp-ks.conf`.

- MCP\_KS\_PG / `pg`

    Postgres connection string for the shared store. Required.

- MCP\_KS\_TOKEN / `token`

    A bootstrap bearer token, accepted in addition to the tokens in the
    database. It exists to reach a fresh deployment before any token has been
    minted; it cannot be revoked without a redeploy, so drop it once
    `token add` has been run. When unset, only database tokens are accepted.

- MCP\_KS\_NO\_MIGRATE

    Set to skip running migrations at startup, for when the schema is managed
    out of band.

- MCP\_KS\_NO\_PURGE

    Set to a true value (e.g., `1`) to disable the `purge_*` tools across all
    resource types. When disabled, calls to any purge tool will return an error.
    This allows deployments to prevent permanent deletion while still allowing
    archive/restore operations. Archive provides soft deletion that preserves
    all data and history for audit purposes.

- MOJO\_LOG\_LEVEL

    Sets the Mojolicious log threshold. Supported values are `trace`, `debug`,
    `info`, `warn`, `error`, and `fatal`. The default is `trace` in
    development mode and `info` in other modes.

    Successful tool calls are logged at `info`. Arguments and replies are logged
    at `debug`, and raw request and reply envelopes at `trace`. Unknown tools
    and requests rejected by the HTTP transport are `warn`, while tool failures
    and exceptions are `error`. `fatal` remains available for unrecoverable
    server conditions.

# ATTRIBUTES

## store

The [MCP::Server::KnowledgeStore::Store](https://metacpan.org/pod/MCP%3A%3AServer%3A%3AKnowledgeStore%3A%3AStore) the tools operate on, built from the
configuration above.

## mcp\_server

The assembled [MCP::Server](https://metacpan.org/pod/MCP%3A%3AServer) - see [MCP::Server::KnowledgeStore::Tools](https://metacpan.org/pod/MCP%3A%3AServer%3A%3AKnowledgeStore%3A%3ATools). Exposed
so a tool can be registered on it after startup, which is how the test
suite verifies token attribution without depending on any resource
plugin.

# METHODS

## startup

Migrates the database, mounts the MCP endpoint at `/mcp` behind
bearer-token authentication, and a `/health` check that verifies the
database is reachable.

# SEE ALSO

[MCP::Server::KnowledgeStore::Store](https://metacpan.org/pod/MCP%3A%3AServer%3A%3AKnowledgeStore%3A%3AStore), [MCP::Server::KnowledgeStore::Tools](https://metacpan.org/pod/MCP%3A%3AServer%3A%3AKnowledgeStore%3A%3ATools), [MCP::Server](https://metacpan.org/pod/MCP%3A%3AServer).
