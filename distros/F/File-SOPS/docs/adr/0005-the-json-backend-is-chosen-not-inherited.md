# ADR 0005 — The JSON backend is chosen, not inherited: `Cpanel::JSON::XS`

- Status: accepted
- Date: 2026-08-09
- Tags: json, interop, wire-format, dependencies
- Resolves k56; amends what k49 pinned in `t/11-api-edges.t` (f)
- Depends on ADR 0002 (a value's type comes from the scalar) and ADR 0001 (the
  MAC is verified against a reparse of the document, so what the emitter wrote
  and what the parser reads back are both wire questions)

## Context

`File::SOPS::Format::JSON` emitted and parsed through `JSON::MaybeXS`, which
binds to a backend **once per process, by load order**:

```perl
return "Cpanel::JSON::XS" if $INC{"Cpanel/JSON/XS.pm"};
return "JSON::XS"         if $INC{"JSON/XS.pm"} && eval { JSON::XS->VERSION(3.0); 1 };
# ... otherwise require Cpanel::JSON::XS, then JSON::XS, then JSON::PP
```

Whoever loads it first decides, and this distribution is not the only claimant:
`File::SOPS::Encrypted` loads CryptX, which loads `JSON.pm` and with it
`JSON::XS`. `File/SOPS.pm` currently wins that race only because its
`use JSON::MaybeXS` sits above its `use File::SOPS::Encrypted` — an ordering,
not a guarantee:

```
perl -Ilib -MFile::SOPS -e 'print JSON::MaybeXS::JSON()'          # Cpanel::JSON::XS
perl -MJSON::XS -Ilib -MFile::SOPS -e 'print JSON::MaybeXS::JSON()'  # JSON::XS
perl -Ilib -MFile::SOPS::Encrypted -MJSON::MaybeXS -e '...'          # JSON::XS
```

So the same data was written two ways by the same library, decided by what the
*calling program* had loaded. For a library whose stated purpose is
git-friendly diffs, that alone is a defect. The measurements below say it is
also a correctness defect, in both directions, and that the fix is not the one
k56 proposed.

### What the three backends write (Perl 5.36, Cpanel 4.40, JSON::XS 4.04, JSON::PP 4.16)

Only **floats** differ. Integers, strings, booleans, `null`, key order, UTF-8
output and pretty-printing are byte-identical across all three, so encrypted
values — which are `ENC[...]` strings on the wire — are untouched by any of
this. So are the metadata fields, which are strings, integers and booleans.

| Perl scalar (NOK) | Cpanel::JSON::XS | JSON::XS | JSON::PP | `sops` writes |
|---|---|---|---|---|
| `1.0`             | `1.0`  | `1`   | `1`   | `1`  |
| `-0.0`            | `-0.0` | `-0`  | `0`   | `-0` |
| `1.5`             | `1.5`  | `1.5` | `1.5` | `1.5` |
| `1e20`            | `1e+20` | `1e+20` | `1e+20` | `100000000000000000000` |
| `0.1+0.2`         | `0.3`  | `0.3` | `0.3` | `0.30000000000000004` |

### What they read back

`File::SOPS::Encrypted->value_to_bytes` of the decoded scalar — i.e. the bytes
that go into the MAC digest — for a document containing that text:

| JSON text | Cpanel::JSON::XS | JSON::XS | JSON::PP |
|---|---|---|---|
| `0.3` | `0.3` | **`0.30000000000000004`** | `0.3` |
| `0.7` | `0.7` | **`0.7000000000000001`** | `0.7` |
| `1.0` | `1` | `1` | `1` |
| `-0.0` | `-0` | `-0` | `-0` |
| `-0` | `0` | `0` | `0` |
| `12345678901234567000` | same digits | same digits | same digits |

**JSON::XS's decoder is not correctly rounded.** It is off by one ULP on
ordinary short decimals, so it does not merely format differently — it hands
back a *different number* than Go's `strconv.ParseFloat` produced from the same
text.

### The two failures, reproduced against sops 3.13.3

1. **Reading a valid sops file fails.** `sops --encrypt` on
   `{"third_unencrypted": 0.3, "secret": "x"}` writes `0.3` and reads it back
   itself (exit 0). File::SOPS reads it correctly under Cpanel::JSON::XS and,
   in a process that loaded `JSON::XS` first, refuses it:

   ```
   MAC verification failed: the digest over 2 leaf values in document order
   does not match the one stored in the sops section.
   ```

   The digest is right and the parse is wrong: `0.3` came back as the double
   whose shortest form is `0.30000000000000004`. The MAC is what caught it; a
   caller passing `ignore_mac` would have been handed the wrong value.

2. **Writing `-0` produces a document nobody can read.** Under JSON::XS an
   unencrypted `-0.0` is written as `-0`; the digest covers `-0` (the float),
   but `-0` parses back as the *integer* zero, which digests as `0`. Our own
   decrypt fails, and so does `sops -d` (`MAC mismatch`, exit 51). Under
   Cpanel::JSON::XS the same value is written `-0.0`, and both implementations
   verify it.

   This is not a divergence from the reference — it is a bug **in** the
   reference, and it is reproducible on its own:

   ```
   sops --encrypt --unencrypted-suffix _unencrypted  # {"negzero_unencrypted": -0.0}
   →  "negzero_unencrypted": -0,
   sops -d <that file>   →  MAC mismatch, exit 51
   ```

   sops 3.13.3 cannot read back a JSON document it just wrote. Matching its
   bytes here would import that.

So k56's premise — "sops agrees with JSON::XS, not with the backend we
land on" — is true about the bytes and false about the outcome. Of the two
renderings, only Cpanel's produces documents both implementations accept.

`1.0` versus `1` is the one genuinely cosmetic difference: both parse back to
the same float64, both digest as `1`, and `sops -d` accepts our `1.0` (exit 0).

## Decision

**`File::SOPS::Format::JSON` names its backend: `Cpanel::JSON::XS`**, for the
emitter *and* the parser, through one object built once — the same single
entry point the encoder already was. `JSON::MaybeXS` is no longer consulted for
anything that touches a document.

`Cpanel::JSON::XS` becomes a direct runtime prerequisite, at the version
`JSON::MaybeXS` itself asks for (4.38).

`JSON::MaybeXS` stays a prerequisite and stays in use where the backend cannot
reach the wire: `JSON->true` / `JSON->false` in `File::SOPS::Encrypted` and
`File::SOPS::Metadata`. All three backends bless booleans into
`JSON::PP::Boolean` (measured), so that object is backend-independent — which
is exactly why k49 was right that the boolean guarantee does not come from
`File/SOPS.pm`'s use line.

### Alternatives rejected

1. **Pin `JSON::XS`, to match the bytes sops writes.** This is what k56
   leaned towards. It buys `1` and `-0` and costs both failures above: valid
   sops documents rejected on read, and `-0` documents that fail their own MAC
   on write. The reference's own bytes are not the specification when the
   reference cannot read them back.
2. **Keep `JSON::MaybeXS` and format numbers ourselves.** There is no portable
   way to hand a JSON encoder a raw number: all three backends emit any scalar
   with a PV as a *string*, so a pre-rendered number would come out quoted.
   Doing it properly means writing our own JSON emitter — and, because of
   failure 1, our own number *parser* as well. That is a far larger wire
   surface than this defect justifies, and it would put string escaping and
   UTF-8 handling back into this distribution's own code.
3. **Accept the divergence and document it.** Leaves output dependent on the
   calling program, and leaves File::SOPS rejecting valid sops files in any
   process that has `JSON::XS` loaded — including one that merely loaded
   `File::SOPS::Encrypted` before `File::SOPS`.
4. **Pin `JSON::PP`, which is core and adds no dependency.** Its decoder is
   correct, but it writes `0` for `-0.0` — the sign is gone from the document
   while the digest still covers `-0`, so the file fails its own MAC exactly as
   in failure 2. It is also the slowest of the three on every document.
5. **A preference chain — Cpanel if present, else JSON::PP, else JSON::XS.**
   Deterministic within an install, not across installs: two machines would
   still write different bytes for the same input, which is the same defect
   with a longer reproduction. And the fallbacks are not equivalent (4), so the
   chain hides a correctness cliff behind an installation detail.

## Consequences

### Whose bytes move

Nobody's, in a process that loads `File::SOPS` the ordinary way: the pinned
object is byte-identical to `JSON::MaybeXS->new(utf8 => 1, pretty => 1,
canonical => 1)` when Cpanel is the backend, which is what that process already
got. Verified over a document with unicode keys and values, booleans, nulls,
nested maps, arrays, integers and floats.

What changes is a process that had `JSON::XS` loaded first. Its JSON output
moves for floats only:

| unencrypted value | before (JSON::XS) | after |
|---|---|---|
| `1.0` | `1` | `1.0` |
| `-0.0` | `-0` (fails its own MAC) | `-0.0` (verifies) |
| `1.5`, integers, strings, booleans | unchanged | unchanged |

Documents written earlier under JSON::XS stay readable, with one exception that
was never readable: a `-0` written for a float value failed its own MAC when it
was written, here and in sops. Nothing about that is recoverable from the file
and nothing about it changes — a document containing `-0` under
`unencrypted_suffix` was already broken.

The **YAML path is untouched**. It has no backend choice — `YAML::XS` is the
emitter and the parser — so nothing there was ever caller-dependent.

### Parsing gets stricter, deterministically

`JSON::XS` accepts duplicate keys (last wins); `Cpanel::JSON::XS` refuses
(`Duplicate keys not allowed`). That refusal is now the answer in every
process rather than in most of them. A document with duplicate keys cannot have
a well-defined MAC — the digest is taken over one of the two values and the
document carries both — so refusing it is the correct half of the coin.

### A new hard dependency

`Cpanel::JSON::XS` is XS and must compile. In practice it is already installed
wherever `JSON::MaybeXS` was installed with a compiler available and without a
recent `JSON::XS` present, which is the common case; the cost falls on installs
that have `JSON::XS` and were relying on `JSON::MaybeXS` finding it. That is
the install this ADR is about: it is precisely where File::SOPS silently read
and wrote a different wire format.

### What `File/SOPS.pm`'s `use JSON::MaybeXS` still does

Nothing to the wire, as of this ADR. Commit 36aafbd kept that line with a
comment saying it decides the JSON backend and that deleting it is a wire
change; that is no longer true, and the comment is corrected to say so. Whether
the line goes is the API lane's call (k49 closed against a premise that
this ADR has now changed) — this ADR only stops it from being load-bearing.

The test k49 left in `t/11-api-edges.t` (f) asserts that loading
`File::SOPS` picks the same backend `JSON::MaybeXS` would on its own. That
claim is still true and still passes, but it is no longer the thing that
protects the wire format; the new checks in `t/23-json-backend.t` are, and they
assert what actually matters — identical bytes out and identical values in,
from a fresh process, whatever it loaded first.

### What this does not fix

Two float defects survive, both of them backend-independent and both of them
older than this ADR. They are recorded as their own tickets rather than folded
in here:

- **15-significant-digit truncation on the way out.** All three backends and
  `YAML::XS` render a double with `%.15g`, while `value_to_bytes` digests the
  shortest form that round-trips (up to 17). So an unencrypted `0.1+0.2` is
  written `0.3` and hashed `0.30000000000000004`: the document fails its own
  MAC and sops's, in *both formats*. sops writes such a value with full
  precision. (k58)
- **Non-finite floats.** `+Inf` reaches JSON as `null` under Cpanel (the value
  is gone) and as the invalid token `inf` under JSON::XS; YAML writes `Inf`.
  The digest says `+Inf` in all three cases, so nothing round-trips. (k59)

## Notes

Every table and every exit code above was measured on this machine against
`sops 3.13.3`, Perl 5.36.0, Cpanel::JSON::XS 4.40, JSON::XS 4.04, JSON::PP
4.16 — not read off documentation, and not derived from the Go source.

The regression check lives in `t/23-json-backend.t` and needs no binary: it
runs the emitter and the parser in **fresh child perls** with `JSON::XS`,
`Cpanel::JSON::XS` and `JSON::PP` preloaded in turn and requires identical
results, because the defect is invisible to any test that runs inside a process
that has already bound the backend — which every `.t` in this suite does at its
`use JSON::MaybeXS` line.
