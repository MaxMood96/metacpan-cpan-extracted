# ApiKeyDemo

`Punk::Plugin::APIKey` end to end: keys minted in a browser, spent from a
terminal, scoped, revocable, rate limited per key, and answerable to their
owner's current standing.

Generated with `punk new ApiKeyDemo --sqitch sqlite` and then wired up, so
the layout is the one `punk new` gives everybody.

## Running it

```sh
punk sqitch deploy      # two projects: the plugin's, then this one's
plackup app.psgi        # or: hyperman app.psgi
```

Then open <http://localhost:5000/>, sign in with any address containing an
`@` (there is no password - see below), and mint a key.

`punk sqitch deploy` is the first thing worth watching:

```
# project punk_apikey (.../Punk/Plugin/APIKey/sqitch)
  + api_keys .. ok
# project apikeydemo
  + users .. ok
  + notes .. ok
```

The `api_keys` table is not in this application's schema. The plugin ships
its own Sqitch project and registers it, and it deploys **before** this
project because a plugin's schema cannot depend on the application's.

## Spending a key

Mint it with `read write admin` to run all four of these - each block needs
the scope above it, and a key holding only `read` gets `403 Forbidden` on the
write. That is the guard working.

```sh
KEY=sk_live_...

# read
curl -H "Authorization: Bearer $KEY" localhost:5000/api/v1/whoami
curl -H "Authorization: Bearer $KEY" localhost:5000/api/v1/notes

# write
curl -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' \
     -d '{"body":"from CI"}' localhost:5000/api/v1/notes

# admin
curl -H "Authorization: Bearer $KEY" localhost:5000/api/v1/admin/stats
```

`/whoami` answers with both sets of scopes, which is the point of it:

```json
{ "owner": 1, "kind": "live", "label": "curl",
  "prefix": "sk_live_-yraveOc",
  "scopes":  ["admin","read","write"],
  "granted": "read write admin" }
```

`granted` is what the key's row says. `scopes` is what the guard actually
tested, after the owner's current role narrowed it.

## The four things worth clicking

**Mint one.** The key is printed once. Nothing stored it: the row keeps a
SHA-256 digest and a `prefix` of the kind prefix plus the first eight random
characters - enough to recognise a key in a list, not enough to rebuild one.
The keys page prints prefixes and never a whole key.

**Demote yourself.** `/api/v1/admin/stats` starts answering 403 and
everything else keeps working:

```
after demote:
  stats:  403
  notes:  200
  whoami: {"scopes":["read","write"], "granted":"read write admin", ...}
```

The key's row did not change. `scope_rank` maps each scope to the minimum
rank on `auth`'s ladder that may exercise it, and a scope the owner's role no
longer reaches is dropped from the effective set for that request. A former
admin's CI keeps deploying and stops administering, which is what demotion
means.

**Suspend yourself.** Every route answers **403**, not 401. The caller has
already proved they hold the key, so there is nothing to enumerate and "your
account is suspended" is the useful answer rather than a lie about the
credential.

**Revoke a key.** It answers 401 from then on, and the row stays in the list:
revoking is a timestamp, not a delete, so the audit of what was revoked when
survives.

## Refusals

Every reason a credential is not good - missing, malformed, a bad checksum,
an unknown kind, an unknown digest, revoked, expired, an owner who is gone -
is one **401** with `WWW-Authenticate: Bearer` and the same body:

```
no key:  401 WWW-Authenticate: Bearer
typo:    401
```

A client that could tell "unknown" from "revoked" could enumerate keys. A
scope the key lacks is a **403**. There is no redirect and no content
negotiation: a browser is not what is on the other end of a key.

The last six characters of a key are a CRC32 checksum in base62, so a
truncated or mistyped key is refused **before the database is touched** - and
a secret scanner can recognise the format and revoke a leaked key before
anyone uses it.

## From the command line

`punk apikey` reads this application's own configuration, so the table, the
kinds and the scope vocabulary are the ones it declares:

```
$ punk apikey list
id  owner  kind  label  prefix            scopes            last used  state
1   1      live  curl   sk_live_-yraveOc  read write admin  36s ago    live

$ punk apikey issue --owner 1 --label deploy --scopes read
$ punk apikey revoke 1
```

## Where to look

| file | what |
|---|---|
| `lib/ApiKeyDemo.pm` | the routing table and the whole plugin configuration - read this first |
| `config/punk.yml` | views, static, the SQLite dsn, the models |
| `lib/ApiKeyDemo/Controller/Web/Keys.pm` | minting, listing, revoking, and the standing switches |
| `lib/ApiKeyDemo/Controller/API/V1.pm` | what sits behind the guards |
| `sqitch/` | this project's `users` and `notes`; `api_keys` comes from the plugin |
| `t/01-basic.t` | the whole story above, asserted |

## Two things this demo is not

**There is no password.** Signing in takes an email and creates the account
on first sight, because a password field would be the one part of this nobody
needed to read. `Punk::Auth` has the other half, and `$c->login` is the same
call either way.

**The standing switches are self-service.** Demoting and suspending yourself
from your own account page is not a design anybody should copy - they are
there so the effect on a live key is one click away.

Two details in the code that are worth copying, though:

- `plugin 'APIKey'` is declared in `lib/ApiKeyDemo.pm` rather than in
  `config/punk.yml`, because `scope_rank` names rungs on the ladder `auth`
  declares and a plugin configured in the file registers at the point the
  `config` keyword sits - before `auth` has run.
- `Web::Keys::_set` calls `Punk::Plugin::APIKey->forget_owners($c->app->caller_class)`
  after changing a role or standing. The plugin caches the owner for
  `owner_ttl` seconds per worker, so without it the switch appears to do
  nothing for up to that long.

## Tests

```sh
prove -l t
```

The suite deploys its own schema into `var/test/` first - its own directory,
because Sqitch keeps the SQLite registry beside the target database and a
test database sharing a directory with the development one would be told
everything was already deployed.
