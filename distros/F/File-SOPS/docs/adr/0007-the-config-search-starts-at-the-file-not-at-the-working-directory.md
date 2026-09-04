# ADR 0007 — The `.sops.yaml` search starts at the file, not at the working directory

- Status: accepted
- Date: 2026-08-09
- Tags: api, interop, config, policy
- Resolves k55 (the confirmation; the implementation shipped under k38)

## Context

`creation_rules_for` walks up from the directory of the **file** it was handed,
looking for a `.sops.yaml`. sops walks up from the **current working
directory**. This is the only place where this distribution knowingly behaves
differently from the reference implementation, and unlike a formatting
difference it decides **who can read the secret**: the rule that matches
supplies the age recipients.

Measured independently on sops 3.13.3, with a config at the tree root
(`encrypted_suffix: _OUTER`) and another at `a/b/` (`_INNER`), file at
`a/b/c/s.yaml`:

| invocation | rule selected |
|---|---|
| `sops -e a/b/c/s.yaml`, run from the tree root | `_OUTER` |
| `sops -e s.yaml`, run from `a/b/c` | `_INNER` |
| `creation_rules_for(file => …)`, from any directory | `_INNER` |

Also measured: `sops -e /abs/path/secrets.yaml` run from an unrelated directory
reports `config file not found`, however many config files sit above the file.

The two searches agree whenever a repository has a single `.sops.yaml` at its
root and the file sits somewhere beneath it — the common case by a wide margin,
where nothing is observable. They diverge only when config files are nested.

## Decision

**Keep the file-based search.** A library is handed a path; the caller's working
directory is not part of the question it was asked. A daemon whose cwd is `/`
would otherwise never find a config, and the same call in the same program would
answer differently depending on where the process happened to be started.

Where the two searches disagree, walking up from the file picks the nearer and
more specific config, which is the one a person editing that file would expect
to apply to it.

Callers who need the other behaviour are not stuck: `config => $path` names a
config file explicitly and skips the search entirely — the equivalent of sops's
`--config`. That argument already exists, and it is what makes this decision
cheap to live with rather than a dead end.

## Consequences

- A file encrypted through this library can end up readable by a different set
  of people than the same file encrypted with the `sops` CLI from a different
  directory. This is only reachable with nested config files, and it is stated
  in the POD for `creation_rules_for` rather than left to be discovered.
- `$SOPS_CONFIG` is still not read from the environment, for the same reason
  the cwd is not consulted: an environment variable that redirects which public
  keys a secret is encrypted to is a reasonable thing for a person to set for a
  command they are running, and not something a library should obey on behalf of
  a caller who never asked. `config => $ENV{SOPS_CONFIG}` is one line.
- Both behaviours stay pinned, deliberately: `t/22-creation-rules.t` asserts
  that our answer does not depend on the working directory, and
  `t/04-interop.t` asserts that sops's does. If either is ever changed, the
  other test is the reminder that the pair is the point.

## Rejected alternatives

**Match sops exactly and search from the cwd.** It is the strongest reading of
"interop is the product", and it was rejected because the property it trades
away is worth more than the divergence costs: that the answer depends only on
the arguments. It would also make `creation_rules_for` useless to exactly the
callers a library exists for — daemons, build steps, anything whose working
directory is incidental.

**Search from the file, but croak when a cwd-based search would have found a
different config.** Fails loud in the ambiguous case, which is the house style,
but it refuses to work where sops simply works, and the ambiguity is not the
caller's fault. It only makes sense paired with a way to resolve it — and since
`config => $path` already exists as that way, the croak adds a failure mode
without adding an escape. Rejected as the most expensive of the three for the
least gain.
