---
name: api-docker-core
description: "Use when working on the API::Docker distribution's client architecture — the HTTP transport role and its socket handling (unix://, tcp://, TLS), a resource API under API::Docker::API::*, how list/inspect wrap a daemon response into a generated API::Docker::Type::* object via API::Docker::Role::Entity::*, streaming endpoints (build/pull/push/events, the on_event/on_frame/on_chunk callbacks), X-Registry-Auth, or the fixture-driven mock harness in t/. Not for generating the type model itself (spec-to-type.pl, spec/) — that's api-docker-type-model."
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
          └─ _wrap / _wrap_list  → $class->from_data($data, client => ...)
                                    on an API::Docker::Type::* class, with
                                    API::Docker::Role::Entity::* composed
                                    onto that class at load time
```

**`_request($method, $path, %opts)` is the only way out of the process.** Every
resource method goes through it (usually via `get`/`post`/`put`/
`delete_request`). A new endpoint never opens its own socket.

Options: `body` (JSON-encoded), `raw_body` + `content_type` (tarballs for
`/build`), `params` (query string), `headers` (extra request headers),
`on_event`/`on_frame`/`on_chunk` (streaming callbacks, see below).

`_request` prefixes the path with `/v$api_version`. `around _request` in
`API::Docker` triggers `negotiate_version` on the first call that is not
`/version` — so a mock that replaces `_request` must strip the `/vX.YZ` prefix
itself, which `Test::API::Docker::Mock` does.

## Invariants

- **`list` and `inspect` return generated `API::Docker::Type::*` objects**
  (via `_wrap`/`_wrap_list`), everything else returns the raw daemon
  response. Which class depends on the resource: `Networks`, `Volumes`,
  `Plugins`, `Secrets` and `Configs` answer both calls with the same class
  (one swagger definition each — `API::Docker::Type::Network`, etc.), while
  `Containers` and `Images` each have two, with different fields —
  `ContainerSummary`/`ContainerInspectResponse`,
  `ImageSummary`/`ImageInspect` (see `API::Docker::API::Containers/"The two
  container shapes"`). Which resources have one class vs. two is read off
  `spec/v1.51.yaml`, not assumed — a future swagger could add a second
  definition to a resource that only has one today.
- **The seven hand-written entity classes are gone (k84)** —
  `API::Docker::{Container,Image,Network,Volume,Plugin,Secret,Config}`. The
  files still ship, but only as stubs that croak on load and on every method
  call (k92), so installing a new release overwrites the working copy an
  older one left on disk instead of leaving it to shadow the release. Never
  write code against them or treat their POD as current; the objects the
  daemon answers with are the `API::Docker::Type::*` classes above.
- **The composed `client` on an entity is a `weak_ref`**, declared by
  `API::Docker::Role::Entity` and composed into every wrapped
  `API::Docker::Type::*` alongside the resource-specific
  `API::Docker::Role::Entity::*` role. `API::Docker->new->images->list`
  leaves every returned entity with `client => undef`, and the next
  `$image->remove` dies on an undefined invocant. The client must stay in a
  live variable — in library code, in examples, and in tests.
- **Query-string booleans are normalised to `1`/`0`** (`$opts{all} ? 1 : 0`);
  **JSON-body booleans are `\1`/`\0`** (see `Exec::start`), because the engine
  type-checks the body but not the query string.
- **A `params` value that is a hashref is JSON-encoded automatically**, but
  `filters` specifically goes through `API::Docker::Role::Filters`, which
  normalises it into the map-of-string-to-array-of-string shape the engine
  wants (wraps a bare scalar in an array, stringifies numbers, turns a JSON
  or `\1`/`\0` boolean into `'true'`/`'false'`) and croaks on anything else —
  another ref, `undef`, an empty string. Pass
  `filters => { dangling => ['true'] }` and let the role do the rest;
  encoding it by hand double-encodes it.
- **Extra headers go through `headers =>`**, which strips CR/LF. Never
  concatenate a header into the request string.
- `_uri_encode` deliberately leaves `/` and `:` raw so image names survive in
  the path (`/images/library/nginx:1.25/push`).
- `sub push` and `sub kill` shadow Perl builtins inside their packages — that
  is why `namespace::clean` is loaded; always call them as methods.

## Entities: generated types with composed methods, not hand-written classes

`_wrap`/`_wrap_list` build the object with `$class->from_data($data, client
=> $self->client)` — never `new`. A daemon response and a caller-built
object are different name spaces: `from_data` reads only the swagger's own
wire names, so a key it does not recognise keeps its own spelling in
`unknown_fields` instead of being misread as the Perl name of an unrelated
field it happens to collide with, and a value that disagrees with the
declared type costs that one field (recorded in `rejected_fields`) rather
than failing the whole response. `new` stays strict and croaks on both
cases — it is what a caller's own arguments go through. Detail:
`API::Docker::Role::Type`.

The convenience methods (`$container->start`, `$image->remove`, `logs`,
`is_running`, ...) are not on the generated classes. They live in
`API::Docker::Role::Entity::*` roles and are composed onto the generated
`API::Docker::Type::*` classes at load time
(`Moo::Role->apply_roles_to_package`), because the generated files must
match `maint/spec-to-type.pl`'s output byte for byte (`t/spec_to_type.t`
enforces it) — nothing hand-written can live in them. See
`API::Docker::Role::Entity` for why a role composed onto the class, and not
a wrapper class holding one.

Fields carry the swagger's own names in snake_case — `$container->state`,
not `$container->State` — and the model does normalise: a field declared
`Bool` comes back `1`/`0` regardless of what the daemon actually sent
(measured on `Plugin.enabled`), and `TO_JSON` writes it back out as a JSON
boolean rather than the Perl truth value.

## X-Registry-Auth — padded base64url, always sent

The engine requires the header on **every** push, anonymous included, and
decodes it with Go's `base64.URLEncoding`, which **requires the padding**.
Stripping the `=` made every push fail with
`failed to parse "X-Registry-Auth" header ... unexpected EOF` — including the
anonymous case, whose payload `{}` encodes to `e30=`, three characters and one
pad. `_registry_auth_header` produces padded base64url (`tr{+/}{-_}`, no `=`
removal); a bare base64-looking string passed as `auth` is forwarded
untouched.

## Transport behavior that's easy to get wrong

- **Buffers the whole response by default; streaming needs a callback.**
  Every request sends `Connection: close`. With none of `on_event`,
  `on_frame`, `on_chunk` given, `_request` reads the whole response before
  parsing, so `/build`, `/images/create`, `/push`, `/events`,
  `/containers/*/stats` and `logs(follow)` block until the daemon closes the
  connection — an unbounded `events` or `stats` call without one of those
  callbacks never returns. Pass one of the three to consume the response as
  it arrives instead. Detail: `API::Docker::Role::HTTP`'s "Streaming a
  response as it arrives".
- **The buffered streaming return type is not stable.** `_request` first
  tries `decode_json` on the whole body and only falls back to line-by-line
  NDJSON parsing (returning an arrayref of events). A stream that carries
  exactly one JSON object comes back as that hashref, not as a one-element
  array. Callers check `ref` before iterating.
- **A failed build/pull/push is still HTTP 200.** `_request` croaks on status
  >= 400 only; `errorDetail` inside the event stream is the caller's job.
- **TLS is implemented, not stubbed.** `tls => 1` on a `tcp://` connection
  (`unix://` never encrypts, and refuses the combination outright) swaps in
  `IO::Socket::SSL` in place of the plain socket — same reader, same writer,
  same everything above it. `cert_path` names a directory in the `docker`
  CLI's own layout (`ca.pem` as the trust anchor, `cert.pem`+`key.pem` as
  this client's identity), defaulting from `$ENV{DOCKER_CERT_PATH}`;
  `tls_insecure => 1` turns verification off. `IO::Socket::SSL` is a
  recommended, not required, dependency, loaded only once a TLS connection is
  actually opened. Detail: `API::Docker::Role::HTTP`'s "TLS on a tcp://
  connection".
- **No connection reuse.** Each `_request` calls `_reconnect` and closes
  afterwards, streamed or not.

## Tests — `Test::API::Docker::Mock`

`test_docker('GET /images/json' => $fixture_or_coderef, ...)` returns a client
whose `_request` dispatches against the route table (exact key first, then the
key matched as a literal path -- it is `\Q..\E`-escaped, not a regex, so a
metacharacter in a route key means itself). A `GET /version` route is injected
when none is given.

**In live mode `test_docker` ignores the routes entirely** and returns a real
client against `$ENV{API_DOCKER_TEST_HOST}`. An assertion that only holds for
the fixture must sit behind `is_live()`; mutating tests behind `can_write()` /
`skip_unless_write()`, with `register_cleanup` for anything they create.

Fixtures in `t/fixtures/*.json` are captured from a real daemon, so drift stays
detectable — do not hand-roll them. That was not always true until karr k101
(and its follow-up): all eight are now real captures -- see the header of
`t/type_fixture_passthrough.t` for which engine and API version backs each
one, including `containers_list.json`, `container_inspect.json` and
`volumes_list.json`, captured from a disposable container and volume created
and removed for the purpose once an earlier pass found neither engine
reachable from the recapturing machine holding one to read.

**A test helper that repairs its input cannot see the defect.** The push-auth
test used to compute and append the missing base64 padding before decoding, so
it passed both with and against the bug it existed to catch. Decode exactly
what the engine would receive.

Canonical run: `prove -lr t/` (recursive — plain `prove -l t/` would silently
skip a future subdirectory). Single file: `prove -lv t/images.t`.
