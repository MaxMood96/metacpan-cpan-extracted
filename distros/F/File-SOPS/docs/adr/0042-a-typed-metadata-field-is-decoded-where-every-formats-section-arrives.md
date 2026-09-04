# ADR 0042 — A typed metadata field is decoded where every format's section arrives

- Status: accepted
- Date: 2026-08-21
- Tags: metadata, mac, api, interop, env, ini
- Resolves k138, the metadata half handed over from k77
- Implements the decision recorded in ADR 0035, section *"The metadata half of
  k77, and where it belongs"* — this ADR is the measurement that backs it
  and the specification that was missing
- Depends on ADR 0002 (a value's type comes from the scalar — the same
  discriminator is reused here rather than spelled again) and ADR 0022 (the
  flat metadata encoding, which has no types at all)

## Context

A `sops` section holds strings, with exactly two exceptions:

| field | Go type | how sops reads it |
|---|---|---|
| `mac_only_encrypted` | `bool` | `strconv.ParseBool` |
| `shamir_threshold` | `int` | `strconv.ParseInt(s, 0, 64)` |

The first one **selects the digest**. With it set the MAC covers only the
encrypted values, behind a fixed 32-byte `MACOnlyEncryptedInitialization`
block, so the two settings can never produce the same digest for the same
document. Reading it wrong is not a cosmetic error: it computes the wrong MAC
for a document `sops -d` reads at exit 0.

k75 found the hazard in the flat encoding. `File::SOPS::Metadata::Flat->unflatten`
returns every leaf as a **string**, because the ENV and INI stores have no
syntax for a type, so `sops_mac_only_encrypted=false` arrives at
`File::SOPS::Metadata->from_hash` as the string `'false'` — which is **true**
in Perl. Handed to `from_hash` unchanged, it turns a document sops reads into
one this library computes the wrong digest for.

The question the ticket left open was **where the coercion goes**, and the
answer is a measurement rather than a preference.

### sops decodes its metadata section weakly in every format

sops does not parse that section out of the document's own types. It decodes it
through `mapstructure` with `WeaklyTypedInput`, which reads a field's **text**
as the field's type. That is not a property of the untyped stores — it applies
to a **nested YAML** `sops:` section exactly as much.

Measured against sops 3.13.3, by inserting the field into a document sops had
just written and reading the exit code of `sops -d`. Because the option selects
the digest, the exit code *is* the decoded value: exit 0 means `false` (the
digest that covers every value, the one the file was written with), exit 51
means `true` (MAC mismatch — the digest moved), exit 1 means refused.

| `mac_only_encrypted:` | sops | exit |
|---|---|---|
| `false`, `0`, `0.0`, `null`, `~` | false | 0 |
| `"false"`, `"FALSE"`, `"False"`, `"f"`, `"F"`, `"0"`, `""` | **false** | 0 |
| `true`, `1`, `1.0`, `2`, `-1` | true | 51 |
| `"true"`, `"TRUE"`, `"True"`, `"t"`, `"T"`, `"1"` | **true** | 51 |
| `"2"`, `"0.0"`, `"1.0"`, `"tRuE"`, `" false"`, `"false "` | **refused** | 1 |
| `"yes"`, `"no"`, `"on"`, `"off"` — and bare `yes`, `no`, `on`, `off` | **refused** | 1 |
| `[]`, `{}` | refused, *unconvertible type* | 1 |

That is `strconv.ParseBool`'s accepted set exactly — the twelve strings
`1 t T TRUE true True 0 f F FALSE false False` — plus mapstructure's own rule
that an empty string is the zero value. Nothing else. `yes`/`no`/`on`/`off` are
refused whether they are quoted or not, because go-yaml v3 does not resolve
them as booleans either.

The same, one type over:

| `shamir_threshold:` | sops | exit |
|---|---|---|
| `2`, `"2"`, `"+2"`, `"-1"`, `"-0"`, `""`, `"0"`, `"00"` | 2, 2, 2, −1, 0, 0, 0, 0 | 0 |
| `"010"` | **8** — a leading zero is octal | 0 |
| `"0x10"`, `"0X1f"`, `"0b101"`, `"0B11"`, `"0o17"`, `"0O7"` | 16, 31, 5, 3, 15, 7 | 0 |
| `"1_000"`, `"0x_1"` | 1000, 1 — underscores separate digits | 0 |
| `"9223372036854775807"`, `"-9223372036854775808"` | int64's ends | 0 |
| `false`, `true`, `2.7` (bare) | 0, 1, 2 | 0 |
| `"false"`, `"true"`, `"abc"`, `"2.0"`, `"1e3"` | **refused** | 1 |
| `" 2"`, `"2 "`, `"+"`, `"-"`, `"0x"`, `"0b"`, `"08"`, `"0o8"` | **refused** | 1 |
| `"0_"`, `"_1"`, `"1_"`, `"1__0"`, `"0_x1"` | **refused** | 1 |
| `"9223372036854775808"`, `"-9223372036854775809"` | **refused** | 1 |
| `[]`, `{}` | refused, *unconvertible type* | 1 |

`strconv.ParseInt(s, 0, 64)`, with `strconv.underscoreOK`'s rule for the
separators, and mapstructure's empty-string-is-zero in front of it.

**And sops writes the decoded value back.** `sops rotate` on each of those
documents normalises the field: `"0x10"` comes back out as `16`, `"010"` as
`8`, `"1_000"` as `1000`, `true` as `1`, `2.7` as `2` — and
`mac_only_encrypted: "false"` comes back out as **no key at all**, which is the
`omitempty` this distribution already reproduces.

### What the measurement rules out

Putting the coercion in `Metadata::Flat->unflatten` would fix the flat
encoding and leave `mac_only_encrypted: "false"` in a **YAML** document still
reading as Perl truth — the identical bug in the format that has a handler
today. Putting it in the format handlers would write it once per handler, and
there are two of them today and four in the roadmap.

`from_hash` is the one place every format's parsed section arrives, typed or
not.

### Which other fields have this problem

Checked, field by field, against sops's `Metadata` struct and by measurement.
**`mac_only_encrypted` and `shamir_threshold` are the only two that are not
strings.** `version`, `lastmodified`, `mac`, the four encryption rules and the
two comment-based ones are all Go strings, and every per-backend key entry
(`age`, `pgp`, `kms`, `gcp_kms`, `azure_kv`, `hc_vault`) holds only strings —
`recipient`, `enc`, `fp`, `arn`, `created_at` and friends.

Weak decoding does reach the string fields, in the other direction: measured,
`unencrypted_suffix: 3` comes back out of `sops rotate` as `"3"`, `true` as
`"1"` and `false` as `"0"`. That needs nothing here, because Perl's own
stringification produces the same text for each — `JSON::PP::Boolean` numifies
to `1`/`0` and an integer stringifies to its digits — so the suffix a rule
matches with is the same either way. Two divergences were found there and are
**named, not fixed**, because they belong to other lanes and other tickets:

- a float-spelled string field (`unencrypted_suffix: 1e20`) would stringify as
  `1e+20` here and as `100000000000000000000` in Go;
- `version` is weakly stringified and then **semver-parsed**, so sops refuses
  `version: 3`, `3.13` or `true` at exit 1 where this library accepts them.

## Decision

**`File::SOPS::Metadata->from_hash` decodes `mac_only_encrypted` and
`shamir_threshold` the way sops decodes them, and refuses what sops refuses.**

Four properties, all deliberate.

- **Only a string is decoded.** A value the parser already typed passes through
  untouched: a `JSON::PP::Boolean` is the answer already, and a number is what
  Go tests as `!= 0` and Perl tests the same way. The question *is this scalar
  a string or a number* is asked of `File::SOPS::Encrypted->detect_type`, the
  distribution's single type ladder (ADR 0002), rather than answered a second
  time in `Metadata.pm`.
- **A value outside the accepted set dies, naming the field and the value.**
  sops stops at exit 1 on each of them, so refusing is the reference-true
  answer as well as the fail-loud one. Guessing is what this layer has
  repeatedly got wrong.
- **A decoded boolean is a `JSON::PP::Boolean`, never `1` or `0`** — invariant
  6, so the next write emits `true`/`false` rather than degrading it to an
  integer.
- **The base-0 integer grammar is reproduced in full**, not narrowed to decimal.
  `"010"` is the row that decides it: a decimal-only parse would read 10 where
  sops reads 8, silently, and silent disagreement with the reference
  implementation is the defect class this repository keeps producing. int64's
  boundary is asked of `File::SOPS::Encrypted->integer_fits_int64` rather than
  spelled a second time.

**`Metadata::Flat->unflatten` stays faithful and keeps returning strings.** It
is the structural inverse of `flatten` and has no schema; ADR 0035 decided
that and this ADR does not reopen it. `t/38-flat-metadata.t` and
`t/50-flat-store-type-policy.t` pin it and stay correct.

**The constructor is not changed.** `File::SOPS::Metadata->new(mac_only_encrypted => $x)`
still means Perl's truth of `$x`, because that is the only thing the word can
mean in a Perl API. The coercion belongs to reading a **document**, the same
asymmetry `from_hash` already has for the `unencrypted_suffix` default.

## Consequences

**No digest moves for any document sops writes.** Measured before and after the
change, for a YAML and a JSON document with `mac_only_encrypted` absent,
explicitly `false`, and set: the MAC plaintext is `8DAD2C9C…` in the first two
cases and `9B5BB7DF…` in the third, identically before and after, in both
formats, and all six still decrypt here and read at `sops -d` exit 0. Those
documents carry a real boolean out of the parser, so the coercion never fires
on them.

**What does change is what a document carrying TEXT means.** Three cases, and
all three are documents this library previously read differently from sops:

- `mac_only_encrypted: "false"` (and `"0"`, `"f"`, `"F"`, `"FALSE"`, `"False"`,
  `""`) turned the option **on** and computed the wrong MAC. It is now off.
- `mac_only_encrypted: "yes"`, `"no"`, `"on"`, `"off"`, `"2"` and every other
  spelling silently turned the option on. They are now refused, as sops
  refuses them.
- `shamir_threshold: "2"` was carried through `extra` as the string `"2"`; it
  is now the integer 2, and is written back as a bare number the way sops
  writes it.

**The flat metadata encoding becomes usable without a trap in front of it.**
`Metadata::Flat->unflatten` hands `from_hash` a string for every leaf, which is
now the *supported* input rather than a hazard the caller has to close. The ENV
and INI handlers (k36, k37) inherit that.

**A reference where a scalar belongs is refused** rather than reaching an
attribute, where an ARRAY ref would have been Perl-true.

**Two divergences were measured and left open** rather than folded in: the
`1e20`-shaped string field above, and `version`'s semver check. Both are
filed rather than fixed here.

## Rejected alternatives

**Coerce in `Metadata::Flat->unflatten`.** The obvious home, since that is
where the string comes from. Refuted by the measurement: sops's weak decoding
is not flat-specific, so this leaves the identical bug in YAML — the format
that has a handler today — and it would give a schema to a class whose whole
point is not having one.

**Coerce in each format handler.** Two copies today, four with the roadmap, in
the one place where two copies of a rule is this distribution's signature
defect.

**Coerce in the constructor too.** Rejected because it changes what a Perl
caller's `mac_only_encrypted => $flag` means, and because there is no document
there to be faithful to.

**Read a false-looking string as false and everything else as true**, without
refusing. It reads `"false"` right and `"yes"` wrong, and gets the wrong answer
quietly for a document sops stops on at exit 1. Where sops refuses, refuse.

**Parse `shamir_threshold` as a decimal integer only.** Simpler, and wrong on
one measured row in a way nothing would report: `"010"` is 8 to sops and would
have been 10 here.

**Leave `shamir_threshold` verbatim and only validate it.** Tempting, because
nothing in this distribution reads the field — it lives in `extra` and is
carried across a rotate untouched. Rejected because refusing exactly what sops
refuses needs the same grammar anyway, so validating costs what decoding costs;
and because sops itself writes the decoded value back, so decoding is the
behaviour being reproduced rather than an addition to it.

**Model `shamir_threshold` as an attribute.** It would put the field in
`to_hash`'s hands and out of `extra`'s, but this class models what a field
**is** and not what it **means**, and the meaning of a threshold is
`key_groups` — the field this distribution cannot implement (k39). It
stays unmodelled and decoded.

## Notes

Measured against sops 3.13.3 (`/tmp/sops`) with Crypt::Age on this machine, on
2026-08-21: 34 `mac_only_encrypted` spellings and 41 `shamir_threshold`
spellings, one document per row, every age keypair generated for the run, plus
the `sops rotate` round trip for the normalisation column. The fixtures are
invented values, not anyone's secrets.

`t/55-weakly-decoded-metadata-fields.t` carries both tables and asserts them
twice: once against `from_hash` (always) and once against the binary
(interop-gated — without one it skips and proves nothing about sops, which is
the honest outcome).
