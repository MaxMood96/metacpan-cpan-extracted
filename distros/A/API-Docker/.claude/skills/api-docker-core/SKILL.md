---
name: api-docker-core
description: "Use when working on the API::Docker distribution — the HTTP role and its socket transport, a resource API under API::Docker::API::*, an entity class, streaming endpoints (build/pull/push/events), X-Registry-Auth, or the fixture-driven mock harness in t/."
---

# API::Docker — architecture and invariants

A pure-Perl client for the Docker Engine HTTP API. It speaks HTTP/1.1 directly
over the daemon's socket and never shells out to the `docker` binary, so any
engine serving that API works (Podman's rootless socket needs nothing but
`DOCKER_HOST`).

## The three layers

```
API::Docker                     client; host, api_version, negotiation
  └─ with API::Docker::Role::HTTP    _request + get/post/put/delete_request
  └─ ->images / ->containers / ->networks / ->volumes / ->system / ->exec
        API::Docker::API::*      one class per resource, holds `client`
          └─ _wrap / _wrap_list  → API::Docker::{Image,Container,Network,Volume}
```

**`_request($method, $path, %opts)` is the only way out of the process.** Every
resource method goes through it (usually via `get`/`post`/`put`/
`delete_request`). A new endpoint never opens its own socket.

Options: `body` (JSON-encoded), `raw_body` + `content_type` (tarballs for
`/build`), `params` (query string), `headers` (extra request headers).

`_request` prefixes the path with `/v$api_version`. `around _request` in
`API::Docker` triggers `negotiate_version` on the first call that is not
`/version` — so a mock that replaces `_request` must strip the `/vX.YZ` prefix
itself, which `Test::API::Docker::Mock` does.

## Invariants

- **`list` and `inspect` return entity objects**, everything else returns the
  raw daemon response. A new list-shaped method wraps with `_wrap_list`; a new
  `tag`/`prune`/`push`-shaped one returns what the daemon said.
- **Entities hold `client` as a `weak_ref`.** `API::Docker->new->images->list`
  leaves every returned entity with `client => undef`, and the next
  `$image->remove` dies on an undefined invocant. The client must stay in a
  live variable — in library code, in examples, and in tests.
- **Query-string booleans are normalised to `1`/`0`** (`$opts{all} ? 1 : 0`);
  **JSON-body booleans are `\1`/`\0`** (see `Exec::start`), because the engine
  type-checks the body but not the query string.
- **A `params` value that is a hashref is JSON-encoded automatically.** Pass
  `filters => { dangling => ['true'] }` through unchanged; encoding it by hand
  double-encodes it.
- **Extra headers go through `headers =>`**, which strips CR/LF. Never
  concatenate a header into the request string.
- `_uri_encode` deliberately leaves `/` and `:` raw so image names survive in
  the path (`/images/raudssus/karr:user/push`).
- `sub push` and `sub kill` shadow Perl builtins inside their packages — that
  is why `namespace::clean` is loaded; always call them as methods.

## X-Registry-Auth — padded base64url, always sent

The engine requires the header on **every** push, anonymous included, and
decodes it with Go's `base64.URLEncoding`, which **requires the padding**.
Stripping the `=` made every push fail with
`failed to parse "X-Registry-Auth" header ... unexpected EOF` — including the
anonymous case, whose payload `{}` encodes to `e30=`, three characters and one
pad. `_build_registry_auth_header` produces padded base64url (`tr{+/}{-_}`, no
`=` removal); a bare base64-looking string passed as `auth` is forwarded
untouched.

## What the transport does not do

These are design limits, not bugs to fix in passing:

- **No streaming.** Every request sends `Connection: close`, buffers the whole
  response, then parses. `/build`, `/images/create`, `/push`, `/events`,
  `/containers/*/stats` and `logs(follow)` therefore block until the daemon
  closes the connection — an unbounded `events` or `stats` call never returns.
- **The streaming return type is not stable.** `_request` first tries
  `decode_json` on the whole body and only falls back to line-by-line NDJSON
  parsing (returning an arrayref of events). A stream that carries exactly one
  JSON object comes back as that hashref, not as a one-element array. Callers
  check `ref` before iterating.
- **A failed build/pull/push is still HTTP 200.** `_request` croaks on status
  >= 400 only; `errorDetail` inside the event stream is the caller's job.
- **`tls` and `cert_path` are attributes with no implementation.** Nothing in
  `Role::HTTP` reads them; a `tcp://` connection is always plaintext. Wiring
  TLS is new work, not a repair.
- **No connection reuse.** Each `_request` calls `_reconnect` and closes
  afterwards.

Entity classes mirror daemon fields verbatim and normalise nothing:
`$container->State` is a status string from `list` and a hashref from
`inspect`.

## Tests — `Test::API::Docker::Mock`

`test_docker('GET /images/json' => $fixture_or_coderef, ...)` returns a client
whose `_request` dispatches against the route table (exact key first, then the
key as a regex). A `GET /version` route is injected when none is given.

**In live mode `test_docker` ignores the routes entirely** and returns a real
client against `$ENV{API_DOCKER_TEST_HOST}`. An assertion that only holds for
the fixture must sit behind `is_live()`; mutating tests behind `can_write()` /
`skip_unless_write()`, with `register_cleanup` for anything they create.

Fixtures in `t/fixtures/*.json` are captured from a real daemon, so drift stays
detectable — do not hand-roll them.

**A test helper that repairs its input cannot see the defect.** The push-auth
test used to compute and append the missing base64 padding before decoding, so
it passed both with and against the bug it existed to catch. Decode exactly
what the engine would receive.

Canonical run: `prove -lr t/` (recursive — plain `prove -l t/` would silently
skip a future subdirectory). Single file: `prove -lv t/images.t`.
