# ADR 0020 — A JSON number Perl cannot hold is a float, not a string

- Status: **accepted** — implemented across f286764 (parser), bf336ac and
  52aa468 (POD) and 66e0c5b (t/36). Written first as a form decision before
  any code, as k63 asks; the implementing lanes then contradicted it in
  three places, and those corrections are marked where they sit rather than
  smoothed over.
- Date: 2026-08-20
- Tags: int, float, json, yaml, wire-format, interop, parser
- Resolves k63
- Depends on ADR 0002 (the type comes from the SV's public flags — which is
  exactly why the JSON parser has to hand back a different SV, not a different
  label), ADR 0005 (the JSON backend is named, so its decoder's options are
  ours to choose), ADR 0006 (the `roundtrips`/`carrier` pair, and the
  `Math::BigFloat` carrier that writes a canonical decimal into JSON as a bare
  number) and ADR 0011 (a float leaf carrying its own string form is
  **repaired**, which is the path this leaf then takes)
- Neighbour, deliberately **not** resolved here: k101, the same
  magnitude window one step lower, where `assert_representable` refuses a
  document sops itself wrote

## Context

`File::SOPS` rewrites a JSON number wider than Perl's integers as a JSON
**string**. Reproduced against sops 3.13.3, exactly as k63 filed it:

    sops -e writes    "big_unencrypted": 100000000000000000000
    File::SOPS rotate rewrites it as    "100000000000000000000"
    sops -d after rotate                 exit 0

The MAC survives — a `str`'s `value_to_bytes` is its own text, and Go's
`ToBytes` of the string it now reads is the same text — so nothing complains.
What changed is the document's schema, silently, on a file the reference wrote.

The ticket's 2026-08-19 measurement established four things that stand and are
not re-derived here: the ADR 0006 float walk never touches the leaf; the SVs of
a bare and a quoted literal are bit-identical after the plain decode, so any fix
is parse-time; `allow_bignum` on the document decoder retypes every float in
every document; and `Format::JSON::_reject_referenced_leaf` croaks on a
`Math::BigInt` leaf. Its conclusion — that preserving number-ness needs a *new*
carrier class, exempted from both emit guards — turns out to be wrong, and the
two measurements below are why.

### What sops itself does with such a number — which the ticket never asked

k63 measured only the unencrypted slot, where the digest text is all that
matters. Put the same digits in an **encrypted** slot and the reference answers
the type question outright. Measured, sops 3.13.3, one `sops -e` per row:

| literal | `type:` sops writes | plaintext | `sops -d` gives back |
|---|---|---|---|
| `9223372036854775807` | `int` | `9223372036854775807` | `9223372036854775807` |
| `9223372036854775808` | **`float`** | `9223372036854776000` | `9223372036854776000` |
| `100000000000000000000` | **`float`** | `100000000000000000000` | `100000000000000000000` |
| `123456789012345678901234567890` | **`float`** | `123456789012345680000000000000` | `1.2345678901234568e+29` |

**There is no big integer in the SOPS data model.** Past `int64` a JSON number
is a `float64` to Go, in an encrypted slot and an unencrypted one alike, and
sops loses the digits itself: `sops -e` on a plaintext
`{"v_unencrypted": 99999999999999999999}` writes
`100000000000000000000` into the file. Twelve wide literals, positive and
negative, put through `sops -e` and compared against
`Encrypted::value_to_bytes` of the same double: **10 of 10 inside the window
below are byte-identical**, and the two outside it are the ADR 0006 spelling
split (Go's `json.Marshal` switches to `1e+21` where `FormatFloat(v,'f',-1,64)`
stays positional — the same double, and, since Go's MAC calls `ToBytes` and not
`json.Marshal`, the same digest).

So the leaf is not a string that should stay a string, and it is not an integer
either. It is a **float**, and this library is the only one of the two that
thinks otherwise.

### The other format already gets it right

The ticket is filed JSON-only and notes in passing that `YAML::XS` returns a
float for the same digits. That is not a footnote; it is the whole shape of the
fix. Measured, both parsers, same literals:

| literal | `YAML::XS` | `detect_type` | `Cpanel::JSON::XS` | `detect_type` |
|---|---|---|---|---|
| `9223372036854775807` | `IOK+POK` | int | `IOK` | int |
| `18446744073709551615` | `IOK+POK` | int | `IOK` | int |
| `18446744073709551616` | **`NOK+POK`** | **float** | **`POK`** | **str** |
| `100000000000000000000` | **`NOK+POK`** | **float** | **`POK`** | **str** |
| `-9223372036854775808` | `IOK+POK` | int | `IOK` | int |
| `-9223372036854775809` | **`NOK+POK`** | **float** | **`POK`** | **str** |

Both parsers switch at the same magnitude, because that magnitude is **Perl's**
— the IV/UV limit, not anything Go knows about. Past it, `YAML::XS` hands back a
double carrying its own source spelling and `Cpanel::JSON::XS` hands back a
plain string. The first of those is already a leaf class this distribution
handles end to end: ADR 0011 repairs it, `_float_carrier` writes it into JSON as
a bare number, and `t/24` pins it.

Two consequences follow, and both matter for the decision:

- **The fix is format-dependent only in the sense that one of the two parsers is
  already correct.** There is no YAML half of this ticket. Nothing in
  `Format::YAML` moves.
- **The target leaf shape is not new and needs no new machinery.** It is
  `NOK+POK` — a `Scalar::Util::dualvar` — which is precisely what `YAML::XS`
  produces for the same digits.

### The window is narrower than the ticket says, and it has a neighbour

`Cpanel::JSON::XS` returns a plain PV only for a literal it cannot hold in an
IV or a UV. Measured at the boundaries:

| range | plain decode | what happens today |
|---|---|---|
| `… 9223372036854775807` | `IOK` | int, correct |
| `9223372036854775808 … 18446744073709551615` | `IOK` | **`assert_representable` croaks** |
| `18446744073709551616 …` | `POK` | **this ticket** |
| `… -9223372036854775808` | `IOK` | int, correct |
| `-9223372036854775809 …` | `POK` | **this ticket** |

The middle row is a *different* defect in the same neighbourhood and it is
worse: `sops -e` normalises `9223372036854775808` to `9223372036854776000`,
which lands in that window, so **`File::SOPS->rotate` croaks on a JSON document
sops itself wrote** (measured, exit 255, "value is an integer outside the range
the SOPS int type can hold"). It is filed separately rather than folded in here,
because fixing it means reopening the `int64` guard, which this ADR does not
touch.

The window also has a ceiling in practice. Go's `json.Marshal` switches to
exponent notation once the double reaches `1e21`, and `Cpanel::JSON::XS`
decodes anything carrying an `e` as an NV — a float already, which never enters
the PV path. So the literals a sops-written JSON document can actually carry
into that path are the positional ones whose double lies in `[2^64, 1e21)`, and
their negatives — exactly the set measured byte-identical above.

## Decision

**The JSON parser gives a bare numeric literal it could not hold as the same
leaf `YAML::XS` already gives: the double, carrying its source spelling.**

Three parts, and each one is measured rather than modelled.

### 1. The oracle is the decoder's own type map, not `allow_bignum`

`Cpanel::JSON::XS::decode($str, my $type)` fills a **parallel tree of type
constants** without changing what `decode` returns. At every leaf, `2` is
`JSON_TYPE_INT`, `4` is `JSON_TYPE_STRING`. Measured across the corpus and
nested through hashes and arrays:

| literal | plain decode | type map |
|---|---|---|
| `100000000000000000000` | `POK` | **2 (INT)** |
| `"100000000000000000000"` | `POK` | **4 (STRING)** |
| `"5432"` / `"007"` / `"1.50"` / `"true"` / `"1e+20"` | `POK` | 4 (STRING) |
| `5432` | `IOK` | 2 |
| `1.5` | `NOK` | 3 (FLOAT) |
| `true` / `null` | blessed / `undef` | 1 / 256 |

**The map is exact for the only question put to it.** A leaf is a plain PV
after the plain decode for exactly two reasons — it was a JSON string, or it was
a bare integer literal too wide for an IV/UV — and the map separates them
without fail. Fifteen pathological literals (400-digit integers, 400-digit
fractions, `1e309`, `1E+20`, 30 ones) were checked for a third case: **there is
none.** Every plain-PV leaf is 2 or 4. A quoted `"100000000000000000000"` stays
4, and no quoted string is ever called a number.

k63's point 6 dismissed this mechanism because `encode($data, $type)`
rewrites this value as `18446744073709551615`. That is true and it is on the
**encode** side. The map is read here and never handed back to an encoder;
nothing in the document path gains a second serialiser.

It is also the cheap one. Measured on documents of 300 and 3000 leaves, decode
time against the plain decode:

| oracle | 300 leaves | 3000 leaves |
|---|---|---|
| type map | +51% (0.061ms → 0.093ms) | +53% (0.76ms → 1.16ms) |
| `allow_bignum` second decode | **+8313%** (→ 5.16ms) | **+5650%** (→ 43.7ms) |

`allow_bignum` builds a `Math::BigFloat` for every float in the document, which
is what costs the two orders of magnitude — and the objects are then thrown
away, because only the `Math::BigInt` answers are ever read. The type map
allocates small integers.

Passing the type argument does not change the returned data (compared
structurally, identical), and does not weaken the duplicate-key refusal
(measured: still croaks).

### 2. The carrier is a `dualvar`, and it is a plain scalar

For a leaf the plain decode returned as a plain PV and the map calls `INT`, the
parser returns `dualvar($nv, $digits)` — the double the digits name, carrying
the digits as its string half. `$nv` comes from numifying a **copy** of the PV,
so nothing sets a flag on a scalar anyone else holds.

Measured, `dualvar(1e20, '100000000000000000000')`:

| asked | answer |
|---|---|
| SV flags | `NOK+POK` — identical to what `YAML::XS` returns for the same literal |
| `detect_type` | `float` (ADR 0002's `NOK` rung; `_sv_kind` does not read `POK`) |
| `value_to_bytes` | `100000000000000000000` |
| `assert_representable` | passes — the `int64` guard only looks at an `int` kind |
| ADR 0012's integer guard | never fires — that branch is `$kind eq 'int'` |
| ADR 0011's float repair | fires, as designed: Cpanel quotes a PV-carrying leaf, the reparse is not a float, `_float_roundtrips` returns 0, `_float_carrier` writes the canonical decimal as a **bare number** |
| `Format::JSON->emit` | `{ "v" : 100000000000000000000 }` |
| `Format::YAML->emit` | `v: 100000000000000000000` |
| `_reject_referenced_leaf` | never sees it — it is not a reference |

**The guard-versus-fix collision the ticket predicted does not arise**, because
no `Math::BigInt` ever enters the tree. The only one that exists lives in the
oracle's type map as the integer `2`. Confirmed in the other direction: a real
`Math::BigInt` leaf still croaks in both emitters, unchanged, and should.

The `dualvar` is chosen over a bare NV for one measured reason. A bare NV of the
same double emits as `1e+20` in JSON (Cpanel's `%.15g`) — still a bare number,
still correct, but **different bytes from the ones sops writes**. With the
source spelling on it the leaf goes through `_float_carrier`, which writes
`value_to_bytes` — and inside the window that text *is* what sops wrote. The
acceptance condition below is only reachable with the string half.

### 3. It is consulted only where the plain tree has a plain PV

The walk descends the plain tree and the type map together and touches a leaf
only when the plain leaf is a defined, unreferenced scalar with `SVf_POK` and
neither `SVf_IOK` nor `SVf_NOK`. Everything else — every float, every integer,
every boolean, `undef`, every reference — is returned as it came, and the map is
not even read there.

**So the float path is not touched.** That was the open question in the ticket's
framing, and the answer is that the fix cannot reach it: a bare float literal
decodes `NOK`, which fails the gate on its first test.

### What was measured

- **The corpus sweep.** 42 JSON literal shapes — integers at every boundary,
  floats including the ADR 0005/0006 cases, `1e400`, `5e-324`, strings including
  quoted digit strings, booleans, `null`, empty and nested containers —
  through `Format::JSON->parse` and `Format::JSON->emit`, with and without the
  change. **6 rows move. All 6 are this leaf class**, and two of them are the
  same leaf nested inside an array and a hash. No float row, no string row —
  `"100000000000000000000"` quoted is still emitted quoted — no boolean, `null`
  or container row.
- **End to end against sops 3.13.3, 12 wide literals** in unencrypted slots
  (`[2^64, 1e21)`, `≥1e21`, both signs, and the negative `int64` edge):
  our `encrypt` → `sops -d` **exit 0, every value read back as a number**;
  and `sops -e` → our `rotate` → `sops -d` **exit 0, with 11 of the 12
  unencrypted slots byte-identical to what sops wrote**, `1e+21` included.
  Corrected during implementation, where this bullet first claimed all 12: the
  twelfth is `123456789012345678901234567890`, which sops writes as
  `1.2345678901234568e+29` and we write positionally. It is **not** this
  decision's doing — measured on the baseline, that row moves identically,
  because sops's own output there carries an `e`, so `Cpanel::JSON::XS`
  decodes it `NOK` and the gate below never sees it. It is the ADR 0006
  spelling split (`json.Marshal`'s exponent against
  `FormatFloat(v,'f',-1,64)`'s positional form), the same double, the same
  digest, and `sops -d` exit 0 — as the Context section above already predicts.
  The accurate claim is: byte-identical for every slot except a `≥1e21` double
  whose shortest form needs more digits than Cpanel's `%.15g` gives.
- **The ticket's own case**, end to end: `sops -e` writes
  `"big_unencrypted": 100000000000000000000`, our `rotate` leaves it bare and
  unchanged, `sops -d` exit 0. Encrypted slots in the same document come back
  `type:float`, matching sops's own token for the same literal.
- **Cross-format**, since a caller can parse JSON and write YAML: the same
  tree emitted as YAML passes the ADR 0013/0017 foreign-resolution guard
  untouched — Go resolves `100000000000000000000` and `-9223372036854775809`
  as floats and derives the bytes the digest covers — and `sops -d` exits 0.
- `prove -lr t/` 833/833 and `SOPS_BIN=/tmp/sops prove -lr t/04-interop.t`
  32/32, as the state this ADR is written against. No test has been run against
  an implementation, because there is none.

## Consequences

### Wire bytes that move

Only for a JSON leaf that was a bare integer literal outside Perl's IV/UV range.
Inside the window a sops-written document can actually contain, **the digest
does not move at all**: today's `str` digest is the literal's text, and the
float's `value_to_bytes` is the same text, measured 10 of 10. What moves is the
document, from a quoted string back to the bare number it started as.

Outside that window — a hand-written literal whose text is not its double's
canonical decimal, `99999999999999999999` or a 30-digit number — **the digest
does move**, from the source digits to the rounded canonical, and the value the
caller gets back rounds with it. That is not a new loss introduced here: it is
what `sops -e` does to the identical document (measured,
`99999999999999999999` → `100000000000000000000`), and the alternative is to go
on being the only implementation that calls the value a string.

**"Window" above means two different sets, and confusing them is the one way to
misread this section.** The *parse-side* window — which literals take the new
path at all — is the numeric one the Context table draws, everything past the
IV/UV limit. The *digest-stability* window is not numeric: it is "the literal's
text equals its double's shortest round-trip decimal", and it is what the
paragraphs above mean. Every positional literal `sops -e` writes satisfies the
second by construction, which is why the two coincide on a sops-written
document. A **hand-written** literal can sit well inside the numeric range and
still move its digest — `18446744073709551616` is just past `2^64` and digests
as `18446744073709552000`. Verified leaf by leaf during implementation, both
directions, against `f286764^`.

### What changes for existing callers

| input | today | after |
|---|---|---|
| sops-written JSON, wide number in an unencrypted slot, rotated | quoted string | bare number, byte-identical to sops |
| the same in an **encrypted** slot | `type:str` | `type:float`, matching sops's own token |
| **quoted** `"100000000000000000000"` in any slot | `type:str` | unchanged, `type:str` |
| the value from `decrypt`, **unencrypted** slot | a string | a dualvar: numeric, and printing it still gives the digits |
| the value from `decrypt`, **encrypted** slot | a string | the bare NV every decrypted float is — `"$value"` prints **`1e+20`**, not the digits |
| the value from `extract`, either slot | a string | a dualvar, printing all its digits (ADR 0010's shape) |
| the plaintext `decrypt_file` **writes** | a quoted JSON string | a bare number (`1e+20` from an encrypted slot) |
| a bare integer literal that overflows a double (400 digits) | written as a string | **croak** — `assert_representable`'s non-finite guard |
| YAML, any of the above | unchanged | unchanged |

The last two need naming. A document already written by File::SOPS carries the
value **quoted**, and a quoted literal is `STRING` to the oracle, so every such
document keeps verifying and keeps reading back exactly as before. And the
overflow croak is a behaviour change that goes in the right direction: sops
refuses that document itself, at unmarshal time — measured, exit 2,
`strconv.ParseFloat: value out of range` — so a croak is closer to the
reference than the string we write today.

### The overflow row's other half: what the plaintext emitters write

The croak names the **write** paths. The plaintext emitters — `decrypt_file`
and `edit` — call no guard, so on that side the leaf reaches
`canonical_float_tree`, where its `value_to_bytes` is `+Inf`, it matches
`$NO_AGREED_FORM` and it is returned untouched (measured: `roundtrips` is not
called for it at all). Each emitter then renders it from whichever half it
prefers, and the two do not agree. Measured on the same tree —
`Format::JSON->parse` of `{"v":1` followed by 400 zeros — at `f286764^` and at
`3e5e6b0`:

| | `f286764^` | now |
|---|---|---|
| the leaf | `POK` — a string | `NOK+POK` — a float, NV `+Inf`, its 401 digits as its text |
| `detect_type` | `str` | `float` |
| `Format::JSON->emit` | `"100…0"`, quoted | `"100…0"`, quoted — **unchanged** |
| `Format::YAML->emit` | `'100…0'`, quoted | `100…0`, **bare** |

**The moved row is not reachable through a plaintext emitter of this
distribution's own.** `decrypt_file` and `edit` resolve one `$format` and use it
for the parse and for the emit alike, so a tree that came out of
`Format::JSON->parse` is always written by `Format::JSON->emit` — the row that
did not move. Measured end to end through `decrypt_file` on the one document
that gets all the way through: a `sops -e --mac-only-encrypted` JSON file whose
unencrypted slot was then hand-edited to the bare literal, so that the digest
does not cover that slot and verification passes rather than stopping the read.
Output before and after: byte-identical, the quoted string. Without
`mac_only_encrypted` the same edit fails verification and needs
`ignore_mac => 1`, at `f286764^` exactly as now.

The **YAML row above is a JSON parse meeting a YAML emitter, not a YAML
document.** A YAML document is unaffected, as the caller table says: `YAML::XS`
has always handed back the same `NOK+POK` leaf for those digits, so its
plaintext emit was bare before this change as well (measured, `decrypt_file` of
a `sops -e` YAML file, identical at `f286764^`). What that document runs into on
the way in — `assert_representable` refusing a value `sops -e` writes, and a MAC
neither implementation computes the same way — is k102 and predates this
decision.

That leaves a document that barely exists. `sops -e` refuses such a JSON
plaintext at unmarshal time (exit 2) and `sops -d` refuses a hand-edited one the
same way (exit 1) — the reference can neither write it nor read it — this
library croaks before writing one at the row above, and a document File::SOPS
wrote before this change carries the value **quoted** (measured at `f286764^`:
`"v_unencrypted" : "100…0"`), which is `STRING` to the oracle and so never
becomes this leaf at all.

So the bare form is reachable in exactly one place: a caller who takes the tree
from `decrypt` or from `Format::JSON->parse` and hands it to a YAML emitter
itself. That is the `decrypt` row of the table above — a dualvar where a string
used to be — seen through the other format's emitter, and it is a consequence of
this decision rather than a defect in it. A plaintext document has no MAC and no
second reader that has to agree with one, which is why `canonical_float_tree`
passes the leaf through instead of choosing a form for it.

If the quoted form is ever wanted back, the lever is the **parse-time** question
k102 asks — whether a literal that overflows a double should resolve as a
`str`, the way go-yaml appears to resolve it — answered for both parsers at
once. Not the emitter, which would have to read a value's text to tell this
float from any other, and that is the pattern-matching ADR 0002 removed; and in
no case the non-finite guard, which is right about every value it was written
for. Measured and closed as k103.

### Cost

One extra decode-time output parameter and one extra tree walk per JSON parse,
at roughly +50% of the decode. The decode is a small fraction of an
encrypt or decrypt (which do age unwrapping, AES-GCM per leaf and a SHA-512),
so this is not measurable at document sizes a secrets file has. It is a real
cost on a very large document and is stated rather than hidden. No new
prerequisite: `Cpanel::JSON::XS::Type` ships with the encoder ADR 0005 already
pins.

### What it does not do

`Format::YAML` is untouched. The `int64` guard is untouched. The float walk is
untouched. `Math::BigInt` remains refused as a tree leaf in both emitters. No
public API, argument or error message changes except the new croak above.

### Implementation, in lanes and in order

They touch the same three files and must run one after another.

1. **`file-sops-format`** — `Format::JSON::parse` only: the type-map decode, the
   parallel walk, the plain-PV gate, the `dualvar`. The oracle must be read from
   the same `$json` object the document already goes through (ADR 0005), and the
   walk must run on `$data` **after** the `sops` section is split off, so the
   metadata is never rewritten. Nothing in `emit`, nothing in the carrier —
   ADR 0011's path already handles the leaf it produces.
2. **`file-sops-wire`** — verify rather than change, and say so in the POD:
   `detect_type`, `value_to_bytes`, `assert_representable` and
   `canonical_float_tree` all take the new leaf correctly as measured above, and
   `Encrypted`'s POD should name where such a leaf now comes from. Only if a
   measurement here disagrees with the table above does this lane touch code.
3. **`file-sops-api`** — `decrypt`, `decrypt_file` and `extract` hand a caller
   something different for this leaf class than they used to. This sentence
   first said "a dualvar" for all three; measured during implementation, that
   is true only of `extract` (ADR 0010's shape, both slots) and of `decrypt` in
   an **unencrypted** slot. In an **encrypted** slot `decrypt` gives the bare
   NV every decrypted float is — `canonical_float_dualvar`'s own POD says so:
   `decrypt` and `decrypt_file` never call it — so `"$value"` prints `1e+20`
   where the string printed the digits. That is the most visible caller
   consequence of this decision and the corrected table above is where it
   belongs. `decrypt_file` returns no value at all; what moved is the plaintext
   document it writes. This lane also owns whether the overflow croak is
   documented as a refusal alongside the `int64` one.
4. **`file-sops-test-writer`** — a unit file pinning the six moved rows and the
   36 unmoved ones, and an interop section for the two end-to-end directions.
   The interop half is the only proof; a green unit suite is not one.

## Rejected alternatives

**Document the drift** (k63 option a) and **refuse the document**
(option c). Both were taken off the table by the maintainer on 2026-08-20 and
are not re-argued. For the record, the measurement supports that: (a) would
document this library as the only implementation that turns a number into a
string, and (c) would refuse documents `sops -e` writes and `sops -d` reads.

**`allow_bignum` as the oracle**, the shape k63's plan proposed. It works
and it is exact — measured, `Math::BigInt` for every bare wide literal, plain PV
for every quoted one. It costs 55 to 84 times the plain decode, because it
constructs a `Math::BigFloat` for every float in the document to answer a
question asked only about strings. The type map answers the same question for
+51%. Rejected on cost, not on correctness.

**`allow_bignum` on the document decoder.** Re-confirmed as k63 recorded:
`0.30000000000000004` decodes to a `Math::BigFloat`, `detect_type` calls a
blessed leaf `str`, and every float in every document changes type and digest.
The comment in `Format::JSON` already says so.

**`->allow_bigint`, which would be exactly the right knob.** It is a deprecated
no-op in `Cpanel::JSON::XS` — the method body is a single `Carp::carp`
("obsoleted, use allow_bignum") and returns nothing. Named here so nobody
measures it twice.

**A `Math::BigInt` carrier in the tree**, the ticket's assumption. Measured, it
croaks in **both** emitters — `Format::JSON::_reject_referenced_leaf` and
`Format::YAML::_reject_unwritable_leaf` — and both refusals are correct:
`detect_type` calls a blessed leaf `str`, so the digest would cover its
stringification while Cpanel writes a bare number. Exempting it would reinstate
the defect ADR 0006 and ADR 0008 closed. The `dualvar` needs no exemption from
anything.

**A new carrier class of our own**, which is what k63 concluded was needed.
It would need an exemption from both emit guards, a `detect_type` rung, a
`value_to_bytes` branch and a decision about what `decrypt` hands back — four
new places where a second type ladder could grow, for a leaf shape the
distribution already has. The `dualvar` costs none of that because
`YAML::XS` has been handing us one for the same literal all along.

**A bare NV, with the string half stripped.** Simpler, and it fixes the schema
drift just as well: `detect_type` float, correct digest, bare number in the
document. It emits `1e+20` where sops writes `100000000000000000000`, so
rotating a sops-written document would move bytes that are correct today —
the one thing ADR 0006 set as its acceptance condition and this ADR keeps.

**Keep the leaf a `str` and teach the emitter to write it bare.** It preserves
the digits exactly, which is more than sops manages, and it needs no oracle at
parse time. It also needs the emitter to decide, from a string's *text*, that
this particular string is a number — which is the pattern-matching ADR 0002
removed, and it would write `"5432"` bare the day someone loosened the pattern.
Worse, it makes the document and the digest disagree the moment the digits are
not their double's canonical decimal: we would digest `99999999999999999999`
where Go, reading the bare literal it now finds, digests
`100000000000000000000`. A file that fails its own MAC, in exchange for
precision no reader can use.

**Digest the source text and write the source text, as a float.** The same
mismatch from the other side, and it breaks ADR 0006's rule that a float's
digest is `FormatFloat(v,'f',-1,64)` of the double — one type with two digest
rules, which is the drift this distribution names as its signature defect.
