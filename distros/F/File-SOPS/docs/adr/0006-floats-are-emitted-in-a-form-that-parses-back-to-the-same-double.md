# ADR 0006 — Floats are emitted in a form that parses back to the same double

- Status: accepted
- Date: 2026-08-09
- Tags: float, mac, interop, wire-format, json, yaml, dependencies
- Resolves k58
- Depends on ADR 0001 (the MAC's decrypt side reads a reparse of the document,
  so what the emitter wrote is what gets verified), ADR 0002 (a value is a float
  because of its SV flags) and ADR 0005 (the JSON backend is named, which is the
  only reason a fix exists on that side at all)

## Context

`File::SOPS::Encrypted::value_to_bytes` writes a float as Go's
`strconv.FormatFloat(v, 'f', -1, 64)` — the shortest decimal that round-trips,
up to 17 significant digits. That is what the MAC digest covers. Every emitter
this distribution has renders the same double with **15**: `Cpanel::JSON::XS`
through `%.15g`, `YAML::XS` through Perl's own stringification, which is also
15.

For a double that needs 16 or 17 digits the document therefore states one
number and the digest covers another. Measured end to end against sops 3.13.3,
default configuration, no config file needed because `_unencrypted` is the
default suffix:

| value | digest covers | emitted | result |
|---|---|---|---|
| `0.1+0.2` | `0.30000000000000004` | `0.3` | fails its own MAC, `sops -d` exit 51 |
| `1/3` | `0.3333333333333333` | `0.333333333333333` | fails its own MAC, `sops -d` exit 51 |

sops writes such a value at full precision itself and reads it back (exit 0),
so this is ours alone.

### It is not symmetric between the two formats

The trigger is a float SV carrying `NOK` and no `POK`. `YAML::XS` **retains the
PV of every float it parses** — measured for a plain scalar, inside a flow
mapping, inside a sequence, anchored, aliased and nested, all `-NP` — and emits
that PV verbatim and unquoted. `Cpanel::JSON::XS` hands back a bare NV. So a
float that came out of a YAML document survives a YAML round trip by accident,
and one that came out of a JSON document does not:

    sops -e writes   "sum_unencrypted": 0.30000000000000004    sops -d exit 0
    File::SOPS rotate rewrites it as    0.3                    sops -d exit 51

`rotate` and `encrypt_in_place` on a **legitimate sops-written JSON document**
destroy the value and produce a file the reference rejects. The same document
in YAML rotates cleanly. A tree parsed from JSON and emitted as YAML breaks
too, as does any caller-supplied computed float in either format.

Worse, `edit` does not fail at all: it round-trips through the plaintext
emitter, so the value is degraded to `0.3` *before* the digest is taken, both
agree, `sops -d` returns 0, and the number on disk is silently wrong.

### How often this fires, and why nobody hit it

Hand-typed decimals essentially never need more than 15 significant digits —
none of `0.1 0.5 1.5 3.14 2.718 99.99 0.001 1e10 12.34` does. Computed values
almost always do: `1/n` for n=1..1000 needs 16–17 digits in 93% of cases, `n/7`
in 86%, `rand()` in 92%. A hand-written config never trips it; anything
machine-generated does, and Go, Python and JavaScript all serialise floats at
shortest-round-trip by default, so any JSON they produce carries exactly these
literals.

### The requirement is weaker than "emit the canonical form"

Go recomputes the digest by re-deriving `FormatFloat(v, 'f', -1, 64)` from the
value it *parsed*. So the MAC agrees if and only if the emitted decimal
**parses back to the same double** — it does not have to be the canonical
spelling. Verified: a sops document carrying the non-canonical but
round-tripping literal `0.300000000000000044408920985` verifies and rotates
cleanly. This is what makes a minimal fix possible, and it is why the fix is a
predicate rather than a rewrite.

### What each emitter can be made to do (all measured)

| mechanism | result |
|---|---|
| `dualvar(NV, text)` + `YAML::XS` | **works** — emits the text unquoted, as a real scalar |
| `dualvar` + `YAML::PP` / any JSON backend | quoted; becomes a string. No |
| `allow_bignum` + `Math::BigFloat`, `Cpanel::JSON::XS` | **works** — bare JSON number, exact text |
| `allow_bignum`, `JSON::PP` | works |
| `allow_bignum`, `JSON::XS` | **the method does not exist** |
| `Cpanel::JSON::XS::Type`, `JSON_TYPE_FLOAT` | still `0.3`. No |
| `convert_blessed` / `TO_JSON` | quoted. No |
| `YAML::PP` representer, `YAML_PLAIN_SCALAR_STYLE` | works, but see rejected alternatives |

That `JSON::XS` has no `allow_bignum` at all is worth stating plainly: this fix
exists on the JSON side only because ADR 0005 pinned the backend. Under the old
`JSON::MaybeXS` binding it would have been available or not depending on what
the calling program had loaded.

## Decision

**Each emitter renders every float leaf, reparses its own output, and
substitutes a canonical carrier only where the value does not come back as the
same double.**

- The predicate is the real emitter, not a model of it. `Format::YAML` dumps
  and loads through `YAML::XS`; `Format::JSON` encodes and decodes through the
  same `Cpanel::JSON::XS` object the document goes through. Equality is decided
  by comparing `value_to_bytes` of the original and of the reparsed value, so
  the round-trip test and the digest agree on what "the same number" means by
  construction — including the sign of a negative zero, which `==` cannot see.
- **The substituted text comes from `Encrypted::value_to_bytes`.** It is the
  same call the digest makes, on the same scalar. The carrier transports that
  text to the emitter; it does not re-derive it. A second conversion here would
  reinstate this distribution's signature defect — two renderings that drift
  and are then consistently wrong together — so the walk lives in
  `File::SOPS::Encrypted` next to `value_to_bytes` and `_sv_kind`, and the
  format handlers supply only the round-trip predicate and the carrier.
- **The carrier is format-specific.** YAML uses `Scalar::Util::dualvar($nv,
  $text)`; JSON uses `Math::BigFloat->new($text, undef, undef)` with a
  dedicated `allow_bignum` encoder instance.
- **The walk runs on a copy of the tree, at emit time, after the digest.** A
  `Math::BigFloat` leaf is a blessed reference, so `detect_type` would call it
  `str` and `value_to_bytes` would write the wrong bytes. The carriers must
  never be visible to the MAC walk.
- **`NaN`, `+Inf`, `-Inf` and `-0` are excluded** and keep exactly today's
  behaviour. They are a different defect with different answers per format —
  YAML `-0.0` has no representation that works, JSON has none for the
  non-finite values at all — and they belong to k62.

  **Amended by k62 — `-0` is no longer excluded, because the premise
  above was wrong.** "YAML `-0.0` has no representation that works" was
  derived, not measured: the reasoning was that the canonical text `-0` is
  resolved by Go's yaml.v3 as an *integer*, digested as `0`, and so still
  mismatches a digest of `-0`. That much is true. What nobody tried was any
  other spelling. Measured against sops 3.13.3, one document per spelling,
  unencrypted leaf, digest `-0`:

  | emitted | `sops -d` | self-MAC |
  |---|---|---|
  | `0` (what YAML::XS renders) | exit 51 | FAIL |
  | `-0` (the canonical text) | exit 51 | FAIL |
  | `!!float -0` | exit 51 | FAIL |
  | `-0.0` | **exit 0**, reads back `-0` | **OK** |
  | `-0.` | exit 0 | OK |

  So a representation exists, and this ADR's own rule already licenses it:
  the emitted decimal has to **parse back to the same double**, not to be
  spelled canonically. `-0` is dropped from `$NO_AGREED_FORM`, which sends a
  negative zero through the normal predicate-and-carrier path, and
  `Format::YAML::_float_carrier` writes `-0.0` where the canonical text is
  `-0`.

  This is **the only place in the distribution where a written decimal is not
  `value_to_bytes`'s output verbatim**, and that is a real cost: the "one
  conversion, one text" discipline above is what keeps the document and the
  digest from drifting. It is bounded by being a *spelling* rather than a
  conversion — the double is the same one, the digest is untouched, and `-0`
  is the only canonical float text whose integer-versus-float resolution
  changes what a reader digests (every other integral text digests the same
  either way: `3` is `3` as an int and as a float; every text needing a
  fraction already carries a `.`). A general "append `.0` to integral text"
  rule was rejected: it would move bytes for cases nobody has measured, such
  as the >`int64` integral texts the carrier already produces for `1e29`.

  **JSON is untouched and had to be.** `Cpanel::JSON::XS` writes an NV `-0.0`
  as `-0.0`, which reparses as the same double, so the round-trip predicate
  answers yes and the carrier never runs — verified by emitting 31 float,
  string and integer values through both handlers before and after the change
  and diffing: **exactly one line moved**, the YAML negative zero. A guard
  that treated the two formats alike would have destroyed the JSON row, which
  is what ADR 0005 was paid for. `t/24` section 3 pins it and section 9 pins
  the new behaviour.

  **Neither implementation could write this value before.** `sops -e` on a
  plaintext `-0.0` emits `-0` and then rejects its own file with exit 51, in
  YAML *and* in JSON. So `-0.0` is not "the bytes sops writes"; it is the only
  spelling both implementations read back as the double the digest covers.
  There is consequently no sops→us fixture for this value, and the test says
  so rather than inventing one.

  `NaN`, `+Inf` and `-Inf` stay excluded, and k59 has since made them
  unreachable on the encrypt path anyway (`assert_representable` refuses
  them); only the plaintext emitters can still reach the walk with one.

  **Amended by k72 — the READ side dropped the same sign, and no longer
  does.** The amendment above carried a negative zero *out* of the library;
  `File::SOPS::Encrypted::_deserialize_value` was still losing it on the way
  *in*. It converted a `type:float` plaintext with `$data + 0.0`, which is
  positive zero twice over: Perl's `grok_number` settles the text `-0` as an
  **integer** zero, which has no sign to keep, and IEEE round-to-nearest makes
  even a genuine `-0.0 + 0.0` come out `+0.0`. Go's
  `strconv.ParseFloat("-0", 64)` is negative zero.

  Unlike the unencrypted case above, **sops can write this one**: an encrypted
  leaf never reaches its float emitter, so the sign survives into the
  ciphertext. Measured against sops 3.13.3, `negzero: -0.0` encrypted by `sops
  -e` itself, YAML and JSON alike:

  | step | before | after |
  |---|---|---|
  | `sops -e`, then `sops -d` | `-0` | `-0` |
  | our `decrypt` of that document | `+0` (signbit 0) | `-0` (signbit 1) |
  | our `rotate`, then `sops -d` | `0`, exit 0, silently | `-0`, exit 0 |

  The MAC never noticed, in either direction: the digest covers
  `decrypt_bytes`, which is the plaintext `-0`, not the deserialized value. So
  every document involved verified, and what drifted was the value handed to
  the caller — and therefore the document, on the next write.

  **The sign is restored from the plaintext's leading `-`, not from the
  numeric conversion**, because the conversion is where it is destroyed and
  the text is the only place it survives. That is a test on a value's *text*,
  which ADR 0002 forbids — but ADR 0002 forbids it for choosing a value's
  TYPE, from a scalar a caller handed us. Neither half applies here: the type
  came from the `type:` label on the wire, the text is authenticated
  plaintext this module just decrypted, and the question put to it is the one
  thing IEEE arithmetic cannot answer about its own result. The rule is
  "negative sign, and the conversion produced a zero", so it is also right for
  a negative underflow (`-1e-400`), which Go parses to `-0` as well.

  Nothing else on the ladder moves: 33 `type:float` plaintexts through
  `_deserialize_value` and back out through `value_to_bytes`, exactly one row
  changes (`-0`: `0` → `-0`), and it is joined by the four spellings — `-0.0`,
  `-0.00`, `-0e0`, `-0.0e10` — that name the same double.

The acceptance condition is **zero wire-byte movement**: for every value that
produces a document sops accepts today, the bytes are unchanged.

## Consequences

- `Math::BigFloat` becomes a runtime prerequisite. It is core, but it is not
  free: `use File::SOPS` goes from 0.122s to 0.169s, about +38%, and that is
  paid by YAML-only callers too because both format handlers are loaded
  unconditionally. Loading it lazily with `require` inside `_float_carrier` was
  considered and rejected: that callback runs once per affected float, so it
  would put a `%INC` lookup in the hot path to defer a cost a process pays once,
  and it would move a missing-prerequisite failure from load time into the
  middle of writing a document.
- `Math::BigFloat->new` applies **class-global** `accuracy`/`precision` if a
  caller has set them, which silently truncated our text to `0.30000` in
  testing. The explicit `undef, undef` arguments bypass that; a subclass would
  also be immune but `allow_bignum` tests the class name exactly and refuses
  one. There is an assertion on the rendered text because the failure is silent
  otherwise, and it names no value.
- The `dualvar` carrier is a **raw-text primitive with no guard rail**:
  `YAML::XS` emits a dualvar's PV whatever it says, so `dualvar(0.3, 'hello')`
  writes `v: hello` unquoted. That is safe only because the text comes from
  `value_to_bytes`, and it is the reason the text may not be derived anywhere
  else.
- `allow_bignum` whitelists `Math::BigFloat` and `Math::BigInt` for **everyone**,
  not only for our carrier, so a caller-supplied one — which the encoder used to
  refuse outright — would have been written as a bare number silently. That is
  not a laxer input rule but a new instance of the very defect this ADR closes:
  `detect_type` calls a blessed leaf `str`, so the digest covers the object's
  stringification while the document carries a JSON number Go reparses as a
  double, and `Math::BigFloat->new('1.00000000000000000000000000001')` digests
  as 29 digits and reads back as `1`. `canonical_float_tree` therefore takes an
  optional `reject` callback, and the JSON handler refuses both classes by name.
  Callers see a die where they saw a die before, with a message that says why.

  **Amended by k68:** `reject` is called as `$reject->($leaf, $where)`.
  `$where` is that leaf's key path, built by the same recursion, colon-joined,
  or `(document root)` — the shape `File::SOPS::_at_path` already uses for the
  MAC walk's messages, with array indices carried because a diagnostic is not
  an AAD. Both handlers put it in front of their message. The walk returns the
  same tree it always did; the only change is that the refusal says which leaf
  it is about.
- Two emit-and-reparse cycles per float leaf that needs checking. On documents
  of the size secrets files actually are this is not measurable; on a document
  with thousands of floats it would be.
- **`decrypt_file` and `edit` stop losing precision as a side effect**, because
  both go through the same `emit`. That closes the silent-corruption path
  above. `extract` is untouched — it hands the caller an NV, and any
  stringification of that still loses the digits; see k61.
- The two format handlers each grew a predicate and a carrier. They are not a
  duplicated conversion — the conversion is one call in one module — but they
  are two places that must both be updated if a third format handler appears.

### What changes for existing callers

Nothing, for every value that works today: `1.0`, `0.5`, `1e+20`, `1e-20`,
`-0.0` in JSON, `NaN` in YAML all emit the same bytes as before, verified case
by case against the binary. Documents that already fail — the 16/17-digit
floats — start working. No API, no argument and no error message changes.

A caller who was relying on File::SOPS writing `0.3` where sops writes
`0.30000000000000004` was relying on a document neither implementation could
read.

Under the k72 amendment a caller that read an encrypted `-0` back out of
`decrypt` gets `-0.0` where it used to get `+0.0`. `==`, `<` and `sprintf
"%s"` cannot tell the two apart in Perl — `print -0.0` writes `0` — so this is
visible only to code that asks for the sign explicitly (`POSIX::signbit`,
`sprintf "%.1f"`), or that writes the value back out, which is the case the
amendment is about.

## Rejected alternatives

**Derive the digest from the document instead of from the tree** (k58
option b). This inverts ADR 0001, which states that the reparse "supplies order
and nothing else… Nothing YAML::PP produces reaches the digest as data, so a
divergence in how it *represents* a scalar cannot change a MAC". Option (b)
makes that representation the digest's data source, and the two parsers do
diverge: of 29 YAML scalars tested, `YAML::XS` (libyaml, YAML 1.1) and
`YAML::PP` (YAML 1.2 core) resolve **7** differently — `0o17` (`0o17` vs `15`),
`0x1f` (`0x1f` vs `31`), `NULL` and `Null` (string vs undef), `.inf` (`.inf` vs
`+Inf`), `.nan` (`.nan` vs `NaN`), `Inf` (`+Inf` vs `Inf`). It would trade one
wrong-value class for seven. It is also structurally awkward on the encrypt
side, where the digest goes *into* the document as `sops.mac` and so would need
emit → reparse → hash → re-emit, and where encrypted leaves are digested over
plaintext that is not in the document at all — a digest with two sources.
Decisively: it does not fix the bug, it ratifies it. A digest over what the
emitter wrote means storing `0.3` where the caller passed
`0.30000000000000004`, with the document verifying and nothing reported. That
is precisely the `edit` behaviour this ADR removes.

**Refuse a float that does not survive its own emitter** (option c), by analogy
with the `int64` range check. Measured with a prototype: it croaks on
`encrypt` of a float that will be **encrypted** — a value with a perfectly good
wire form, `ENC[...,type:float]` whose plaintext *is* the canonical decimal and
which round-trips through both implementations today. That is where the
`int64` analogy breaks: there no wire form preserves the value, here one does.
It croaks on `rotate` and `encrypt_in_place` of a legitimate sops-written
document, in **both** formats, where `sops -r` succeeds and where our YAML path
succeeds today. And it does *not* fire on `edit`, the one path that silently
corrupts, because the value has already been degraded by then. It also cannot
be written where the ticket put it: "does not survive its own emitter" is a
property of the emitter, and `assert_representable` sees only a scalar, so a
format-blind 15-digit rule would refuse YAML documents that work today. Any
correct version of (c) needs this ADR's emit-and-reparse machinery and then
declines to fix anything.

**Always wrap every float** rather than only the ones that need it. Simpler,
and it fixes the same cases, but it moves bytes for values that are fine today
(`1e+20` → `100000000000000000000`, `1e-20` → `0.00000000000000000001`, JSON
`1.0` → `1`) and it **regresses JSON `-0.0` from exit 0 to exit 51**, because
`Math::BigFloat->new('-0')` drops the sign — undoing what ADR 0005 bought.

**Replace `YAML::XS` with `YAML::PP` as the emitter** and use a representer
hook. It works — `$node->{data}` plus `YAML_PLAIN_SCALAR_STYLE` emits the exact
text unquoted, and `YAML::PP` sorts keys by default so the MAC's sorted-key
premise would survive. It is ADR 0001's rejected option 2, and it moves the
wire bytes of every multi-line string in every document, because `YAML::PP`
writes block scalars where `YAML::XS` writes one-line double-quoted strings.
Not worth it when a dualvar does the job in the emitter we already have.

**A post-pass over the emitted text.** Feasible in principle — `YAML::XS` never
emits a block scalar (checked with embedded newlines, tabs and a 200-character
string) and `Cpanel::JSON::XS` pretty output is one value per line — but it
needs a text-position-to-leaf mapping, which is a parser built out of regexes.
That is the exact defect class ADR 0001 removed, and the one that produced the
`mac:`/`hmac:` collision. Rejected on fragility, not on feasibility.
