# ADR 0013 — A YAML spelling Go's parser resolves differently is refused

- Status: accepted
- Date: 2026-08-20
- Tags: yaml, mac, wire-format, guards, interop
- Resolves k86
- Depends on ADR 0001 (the digest and the document are one mechanism: what the
  emitter wrote is what a reader re-derives the MAC from), ADR 0002 (the type
  comes from the SV — this ADR does **not** touch that, see "Why this is not a
  return to ADR 0002's defect"), ADR 0008 (the rule that a leaf an emitter
  cannot write as the text the digest covers is refused) and ADR 0012 (the same
  rule applied to a scalar; this is the same rule applied to a *reader*)

## Context

`File::SOPS::Encrypted::detect_type` and `value_to_bytes` decide what the MAC
digest covers. `YAML::XS` decides what the document says. Both agree with each
other for every leaf in this ADR — which is why k84's guard, which asks
this emitter to reparse its own output, cannot see any of it.

The disagreement is with **Go**. `YAML::XS` is libyaml, whose resolver is
YAML 1.1 as libyaml implements it; sops parses with `gopkg.in/yaml.v3`, whose
resolver is neither YAML 1.1 nor YAML 1.2 but its own set: it strips `_` from a
number, runs `strconv.ParseInt(s, 0, 64)` — which reads `0x`, `0b`, `0o` and a
**leading zero as octal** — then `ParseUint`, then a YAML-shaped `ParseFloat`,
and before all of that it tries four timestamp layouts. Where the two resolvers
land on different values, the file states one number and its own MAC covers
another.

Measured against sops 3.13.3, one document per row, leaf under `_unencrypted`,
written by this library at 543b59d:

| source | this library | document | Go reads | `sops -d` |
|---|---|---|---|---|
| `0755` | `int` 755 | `0755` | 493 | **exit 51** |
| `010` | `int` 10 | `010` | 8 | **exit 51** |
| `017` | `int` 17 | `017` | 15 | **exit 51** |
| `-010` / `+010` | `int` -10 / 10 | as written | -8 / 8 | **exit 51** |
| `0o10` / `0O10` / `0o7` / `0o0` | `str` | as written | 8 / 8 / 7 / 0 | **exit 51** |
| `0x1f` / `0X1F` / `-0x1f` | `str` | as written | 31 / 31 / -31 | **exit 51** |
| `0b101` / `0b0` | `str` | as written | 5 / 0 | **exit 51** |
| `1_000` / `0_7` / `0_` / `685_230.15` / `1_0.5` | `str` | as written | 1000 / 7 / 0 / 685230.15 / 10.5 | **exit 51** |
| `.inf` `.Inf` `.INF` `+.inf` `-.inf` `.nan` `.NaN` | `str` | as written | ±Inf / NaN | **exit 51** |
| `Null` / `NULL` | `str` | as written | null | **exit 51** |
| `TRUE` / `FALSE` | `str` | as written | true / false | **exit 51** |
| `2015-01-01` | `str` | as written | a time, rendered `2015-01-01T00:00:00Z` | **exit 51** |
| `2015-1-2`, `2015-01-01 12:00:00`, `2015-01-01t12:00:00Z` | `str` | as written | a time, rendered otherwise | **exit 51** |

and, in the same run and by the same mechanism, the rows that **agree**:

| source | this library | Go reads | `sops -d` |
|---|---|---|---|
| `007` / `00` / `000` | `int` 7 / 0 / 0 | octal 7 / 0 / 0 | exit 0 |
| `08` / `09` | `int` 8 / 9 | *float* 8 / 9 | exit 0 |
| `1e3` / `1E3` / `1e+3` / `0755e0` | `int` 1000 / … / 755 | float, same number | exit 0 |
| `True` / `False` | `str` `True` / `False` | bool, digested `True` / `False` | exit 0 |
| `null` / `~` | undef | null | exit 0 |
| `yes` `no` `on` `off` `y` `n` | `str` | string (yaml.v3 dropped YAML 1.1's booleans) | exit 0 |
| `1:30` / `12:30:15` | `str` | string (yaml.v3 dropped sexagesimals) | exit 0 |
| `_7` / `0o8` | `str` | string | exit 0 |
| `2015-01-01T12:00:00Z` | `str` | a time, rendered **identically** | exit 0 |
| `123abc` / `localhost` / `2024-invoice` | `str` | string | exit 0 |

`007` is the row that decides the shape of the guard: it agrees **because 7 is
7 in both bases**, not because a leading zero is harmless. A guard that refused
every leading zero would refuse it, which is the mistake 89ed194 made in the
neighbouring case and which ADR 0011 undid.

`0o10` is the mirror image and decides it in the other direction: **we** call it
a `str` and digest the text, **Go** reads the integer 8. A guard that looked
only at `int` leaves would not see it, and neither would one that looked only at
a leaf whose two halves disagree — there is one half here, and it is a string.

### What sops itself does with `mode: 0755`

Measured, because it decides what the error message can honestly recommend:

```
$ printf 'mode: 0755\n' > plain.yaml && sops -e --age … plain.yaml
mode: ENC[AES256_GCM,…,type:int]
$ sops -d …
mode: 493
```

sops resolves the spelling to **493** and stores that; the source spelling does
not survive `sops -e` in any form, encrypted or not. Two things follow. The
message can tell a caller exactly what to pass instead — the decimal — and say
that it is the same document sops itself would have written. And the **read**
path is unaffected: a document sops wrote never carries an octal spelling,
because sops normalised it away. Measured, a sops-written `mode_unencrypted:
0755` arrives here as `493` and its MAC verifies.

### Where it does not happen

- **JSON is not affected in itself**, and does not need a guard of its own: JSON
  has no octal, no `0o`, no unquoted specials and no timestamps, and
  `Cpanel::JSON::XS` quotes every string. Every row above is either written
  quoted (`"0o10"`, `".inf"`, `"2015-01-01"` — `sops -d` exit 0, measured) or
  refused already by ADR 0012's guard, which fires for **every** int leaf whose
  PV differs from the canonical decimal, `007` and `08` included. This guard is
  therefore YAML-only, and the two do not overlap: measured over the corpus
  below, no row is refused by both, and no JSON row changes at all.
- **Encrypted slots are not affected.** By the time the emitter sees the tree,
  `_encrypt_tree` has replaced every encrypted leaf with an `ENC[…]` string,
  which starts with `E` and is resolved as a string by every YAML parser there
  is. Measured: of the 324 encrypted-slot rows in the corpus, **none** fails,
  before or after this change.
- **`mac_only_encrypted` documents are not affected**, and are deliberately
  left out. There the digest covers encrypted values only, so an unencrypted
  leaf cannot make the document disagree with its own MAC: measured, the same
  `0755` document is `sops -d` exit 0 with the flag set. What remains is that
  sops reads `493` from it where this library reads `755` — a real divergence
  about a value, not about the MAC, and refusing it would refuse a document that
  works today. Filed as k87, and **since ADR 0018 the same check runs there
  and warns** — still refusing nothing, still writing the same bytes.

## Decision

**On the encrypt path, a YAML leaf that the emitter writes as a bare scalar is
refused when this library cannot prove that Go's resolver derives the same bytes
the MAC digest covers.**

Concretely, `Format::YAML::serialize` passes `mac_covered => 1` to `emit`, which
installs a `reject_scalar` callback on the leaf walk that
`File::SOPS::Encrypted::canonical_float_tree` already performs. For every plain
scalar leaf that will be written, the callback:

1. skips the `sops` branch — the digest does not cover it, and the one problem
   it has there (`lastmodified`, resolved by Go as a timestamp) is already
   solved, by `_quote_sops_timestamp` and in the opposite way: by quoting;
2. returns immediately unless the leaf's first character is one Go's resolver
   even looks at (`-+.0-9yYnNtTfFoO~` — `resolveTable` in `resolve.go`). This is
   the whole cost for an ordinary string leaf: one regex match, no conversion;
3. otherwise takes the text the digest covers from **`value_to_bytes`** — the
   one conversion, never a second rendering — and compares it against
   `_go_scalar_bytes`, this module's model of `resolve.go` plus sops's
   `ToBytes`;
4. and, only where those disagree, **asks the emitter** whether the leaf is
   written bare at all: `YAML::XS` quotes a string its own resolver would read
   as a number, a boolean or a null, and a quoted scalar is a string to every
   reader. A leaf that comes out quoted, as a block scalar, or over more than
   one line is accepted.

The refusal names the leaf's key path, the two parsers, and what to pass
instead. It never names the value.

### Why this is not a return to ADR 0002's defect

ADR 0002 removed pattern-matching for **typing**: `looks_like_number`,
`/^\d+$/` and `$v eq 'true'` decided what a value *was*, and got it wrong for
every quoted `"007"` a parser had already typed for us. That is untouched here.
`detect_type` still reads the SV's public flags and nothing else, `value_to_bytes`
still derives the digest from the scalar, and this guard runs after both and
changes neither.

What the text is inspected for is a different question with a different subject:
**what a foreign parser will make of the bytes we are about to write.** That
question cannot be answered from the SV — the SV is on this side of the file.
It is the same shape as `_quote_sops_timestamp`, which has matched a text
pattern in the emitted document since 0.003 for exactly this reason, and the
same shape as the round-trip checks ADR 0006 introduced, which ask an emitter
about bytes rather than modelling a value.

The distinction is worth keeping sharp, because the two look identical from a
distance: **a pattern that decides a value's type is a defect here; a pattern
that decides whether two implementations agree about a document is a
compatibility check.** The first has an authority (the SV) that it is ignoring;
the second has no authority available short of running Go.

### Why a model of Go, and not a measurement

Everything else in this layer asks the machinery itself — `roundtrips` emits and
reparses, `carrier` is chosen by what an emitter does. There is no such oracle
here: the reader whose answer matters is in another process, in another
language, and is not on the encrypt path. `YAML::PP`, this distribution's second
parser, is not a stand-in either — its Core schema resolves `0755` to 755, like
libyaml and unlike Go, so it agrees with the side that is already wrong.

So `_go_scalar_bytes` is a model, and it is treated as one: it is written from
`resolve.go` and sops's `ToBytes`, and every branch of it is **verified against
the binary** over the corpus below rather than trusted. Where the model cannot
decide, it says so and the leaf is refused: `9223372036854775808` and
`0xffffffffffffffff` resolve to a `uint64`, which sops has no case for and
refuses to write at all (`Error walking tree: Cannot walk value, unknown type:
uint64`, exit 23) — measured, so refusing is not a guess.

**Amended by k91 — steps 2 and 4 above have become one step, and it is the
one that asks the emitter.** The leaf's stringification was a proxy for the
token in both the gate and the verdict, and it is the same string for every leaf
class but a boolean, whose token is `true`/`false` while it stringifies to `1`
or to nothing. k90 came through the verdict half by exactly that route. The
gate survives — the cost measurement above is why — with one clause for the leaf
class whose token is not its stringification; the verdict is now taken from the
token alone. Measured: 0 of 900 corpus rows move. See ADR 0017.

**Amended by k89 — the model shared a conversion with the code it was
checking, and lost the same sign.** `_go_float` derived its float with
`value_to_bytes($p * 1.0)`, the arithmetic copy ADR 0014 measured and rejected
one level down. For a negative zero **written with an exponent** — `-0.0e0`,
`-0e0`, `-0.0E+0`, `-0.000e2`, `-0.0e-5` and five more spellings — that
multiplication takes Perl's integer path and returns a plain `0`, so the model
answered `0`, this library answered `0`, the guard saw agreement, and a document
`sops -d` rejects with exit 51 was written silently. Without an exponent `-0.0`
survives `* 1.0` as an `NV`, which is why the guard was right for it and why the
gap outlived this ADR. The conversion is now `unpack('d', pack('d', $p))`, and
the underlying mis-typing is ADR 0015.

The general point is worth more than the fix: a model of a foreign reader that
shares a conversion with the code it checks can only catch the cases where the
two happen to differ. **It agreed with our own wrong answer**, which is this
distribution's signature failure mode wearing the guard against it. The corpus
below is what verifies the model, and it contained no negative zero with an
exponent.

### What was measured

A 648-row emitter corpus — 162 leaves × 2 slots (`x_unencrypted`, `x`) × both
handlers — each row encrypted and then handed to `sops -d`. The leaves are the
spellings above taken through a real `YAML::XS` parse, the same spellings as
caller-supplied Perl strings, the timestamp edges (fractional seconds, offsets,
`2015-02-29`, `2015-01-01T24:00:00Z`), the int64/uint64 edges, plain ints,
floats, the ADR 0005 / 0006 float cases, the ADR 0011 / 0012 dualvars,
booleans, `undef`, an empty string and a non-ASCII string. The "before" side is
the same code with the callback switched off, verified row for row against a
real 543b59d run: **464 shared rows, 0 differ.**

- **53 rows move, and every one of them was already broken**: 50 were `sops -d`
  exit 51 (MAC mismatch) and 3 were exit 25 (`Error walking tree: Cannot walk
  value, unknown type: uint64` — a bare `0xffffffffffffffff`, which sops cannot
  read and, measured, will not write either). Each becomes a croak naming the
  key path.
- **All 53 are YAML, and all 53 are unencrypted slots.** Not one JSON row
  changes, and not one encrypted-slot row: 0 of the 324 encrypted rows fails
  before or after.
- **Nothing that works today stops working.** The remaining 595 rows produce
  byte-identical documents and the same `sops -d` exit codes as before — `007`,
  `00`, `08`, `1e3`, `0755e0`, `-0`, `True`, `null`, `~`, `yes`, `off`, `1:30`,
  `12:30:15`, `_7`, `0o8`, `123abc`, `2024-invoice`, `1234-5678`, `.`, `..`,
  `._5`, `.gitignore`, `2015-02-29`, `2015-01-01T24:00:00Z`,
  `2015-01-01T12:00:00Z` and `2015-01-01T12:00:00.5Z` included.
- A second, false-positive-hunting corpus of **105 values a real config file
  holds** — IP addresses, version strings, ports, UUIDs, phone numbers, dates,
  paths, `.env`, base64-ish secrets — every one of them hinted enough to reach
  the guard: **101 written and verified by `sops -d`, 4 refused**, and all four
  are strings whose spelling libyaml declines to quote (`"1_000"`, `'.inf'`,
  `'2015-01-01'`, `"0o10"`), each measured `sops -d` exit 51 before this change.
  Three earlier drafts of the model were caught by exactly this corpus: `-0`
  (an integer zero has no sign to Go), `2015-01-01T12:00:00.5Z` (sops digests a
  time as RFC3339 **Nano**, which keeps the fraction) and `.` / `..` (Go's
  ParseFloat takes neither).
- The cost, per 1000 leaves through `emit`: a string leaf Go's resolver does not
  look at is **4.6ms → 4.3ms**, i.e. the gate and nothing else; an int or a
  hinted string is **3.4ms → 11.8ms**; a float is **44ms → 64ms**, because the
  model has to render one to compare it. Only the leaves the resolver looks at
  pay anything, and no leaf is emitted twice unless the model has already said
  the document would disagree.
- Counter-check: with the guard switched off and `t/30` kept, **20 of its 32
  subtests and 99 of its assertions fail** — every refusal becomes a silent
  document again.
- `prove -lr t/` was 694/694 at 543b59d and is 726/726 with the new file, no
  existing test edited; `SOPS_BIN=/tmp/sops prove -l t/04-interop.t` 31/31,
  executed, before and after.

## Consequences

- **A croak where a document used to be written.** A behaviour change, and it
  belongs in `Changes` as one — but nothing that worked stops working: every
  input that now croaks produced a YAML file that failed its own MAC, measured,
  `sops -d` exit 51.
- **The plaintext emitters are untouched.** `decrypt_file` and `edit` go through
  `emit` without `mac_covered`, so they still write `.inf`, `2015-01-01` and
  `0755` as they always did. That is deliberate and measured to matter: those
  documents have no MAC for a reader to disagree with, and a guard there would
  refuse to *decrypt* files this library reads correctly.
- **A caller who has `mode: 0755` in a YAML file now hears about it** where the
  file used to be written and rejected later by sops, with a MAC error that
  names nothing. The message says to pass `493`, and that this is what sops
  itself writes.
- The remaining ways to keep the spelling are both in the message: encrypt the
  leaf (an `ENC[…]` string carries any text verbatim, unaffected by this guard),
  or make it a value both parsers read as a string.
- `canonical_float_tree` has a third policy hook. Its POD says what each one is
  for, and that this one is the only one that asks about a reader rather than
  about this distribution's own emitters.

### What changes for existing callers

Nothing for a tree of ordinary strings, numbers, booleans and `undef` — which is
every tree this library produces itself, and every tree in the test suite before
this change (694/694 at 543b59d, unchanged by the guard).
A caller who encrypts a YAML document containing a leading-zero integer, a `0o`
/ `0x` / `0b` number, `_` digit separators, `.inf` / `.nan` / `Null` / `TRUE`,
or a date that is not exactly RFC3339, gets an error naming the leaf's key path
instead of a file that sops rejects with `MAC mismatch`.

## Rejected alternatives

**Quote the leaf on the way out** — k86's candidate (b). It is the fix
`_quote_sops_timestamp` uses for `lastmodified` and it produces a document both
implementations read the same way. It changes the leaf's **type**: `mode: 0755`
becomes `mode: "0755"`, a string where the caller's parser said integer and
where sops itself would have written the integer 493. sops never does this to a
value, and a library that silently retypes a leaf to keep its own MAC intact is
a worse failure than the one it prevents. The maintainer's decision, recorded
here: refuse what we cannot prove, rather than write something nobody asked for.

**Refuse every leading-zero integer.** Two lines, covers `mode: 0755`, and
refuses `007`, `00`, `000` and `08` — all measured `sops -d` exit 0, all
documents this library writes correctly today. It is also blind to `0o10`,
`0x1f`, `.inf`, `Null` and `2015-01-01`, which are the same defect with the same
consequence.

**Refuse only the rows in k86** (`0755`, `010`, `017`, `0o10`). It is the
ticket's literal scope, and the mechanism is one mechanism: the same walk, the
same emitter, the same reader. Half a guard here would have to be widened by
rewriting it, and would leave eleven measured spellings silently broken next to
a guard that says the document is compatible. ADR 0008 deferred its JSON half to
a separate ticket for the opposite reason — there the two halves were two
*emitters*, and each needed its own measurement.

**Put the rule in `assert_representable`.** The same answer ADR 0008 and
ADR 0012 gave, measured again here: it runs over every leaf on the encrypt path,
including the ones about to become `ENC[…]` strings, so it would refuse the 324
encrypted-slot rows that work today. It is also format-blind, and this rule is
about one emitter and one reader of one format.

**Ask `YAML::PP` instead of modelling Go.** It is already a dependency (ADR
0001), it is a second, independent resolver, and it is the wrong one: its Core
schema reads `0755` as 755 and `010` as 10 — the same answer libyaml gives and
the opposite of Go's. A second parser that agrees with the first proves only
that both are consistent, which is the failure mode this distribution ships
against.

**Refuse anything whose first character Go's resolver looks at, without
modelling further.** Cheap, needs no model, and refuses `123abc`, `2024-invoice`
and every numeric-looking identifier — strings both implementations read
identically, measured exit 0. The model exists precisely so the refusal stops at
the leaves that actually disagree.
