# ADR 0011 — A float leaf that carries its own string form is repaired, not refused

- Status: accepted
- Date: 2026-08-20
- Tags: float, json, wire-format, guards, interop
- Resolves k78, and **replaces the refusal that 89ed194 shipped for it**
- Answers k85 in "Why a contradicting float string half is repaired, where
  an integer's is refused"; ADR 0012 states the same boundary from the integer
  side
- Depends on ADR 0006 (the `roundtrips`/`carrier` pair, and the
  `Math::BigFloat` carrier that writes a canonical decimal into JSON as a bare
  number), ADR 0008 (the rule that a leaf an emitter cannot write as the text
  the digest covers is refused — this narrows it) and ADR 0010 (`extract`'s
  dualvar, which is where such a leaf comes from)

## Context

`Cpanel::JSON::XS` writes a scalar carrying a **public** PV as a quoted JSON
string when that PV differs from its own rendering of the number. A float leaf
that carries its own string form — a `Scalar::Util::dualvar` — therefore
reached the document as a **string** where the caller passed a number, and
`File::SOPS::Format::JSON::_float_roundtrips` could not see it: it reparsed the
quoted text, `value_to_bytes` re-derived that same text from it, and the two
compared equal. k78, measured: `"ratio_unencrypted" : "0.30000000000000004"`,
`sops -d` exit 0, value read back **as a string**.

89ed194 closed that by asking the round-trip check one more question — is the
reparsed leaf still a float — and **croaking** when it is not.

The refusal is wider than the case it was written for. `YAML::XS` retains the
source text of every scalar it parses (measured: `1.50` comes back with
`SVf_NOK` **and** a public PV of `1.50`), so *any* float that arrived through a
YAML parse and is emitted as JSON carries its own string form. Measured at
89ed194, `File::SOPS::Format::JSON->emit` on leaves taken straight out of
`YAML::XS::Load`:

| leaf (from a YAML parse) | at 89ed194 | before 89ed194 |
|---|---|---|
| `1.50` | **croak** | `"1.5"` (quoted) |
| `0.30000000000000004` | **croak** | `"0.30000000000000004"` (quoted) |
| `100000000000000000000` | **croak** | `"100000000000000000000"` (quoted) |

So a caller who parses a YAML file and encrypts it as JSON — and the caller of
`extract` that ADR 0010 named — got an error where the same tree written as
YAML has always produced a correct document. YAML writes the string half bare
and, because that half **is** `value_to_bytes`'s canonical decimal, the
document states the number the digest covers: measured, `sops -d` exit 0 with
the value read back as a number, for every float in the corpus below.

The repair the refusal declined to make is one the emitter already has.
`_float_carrier` exists precisely to put a canonical decimal into JSON as a
bare number, and it is reached by returning **false** from `roundtrips`
instead of dying there.

## Decision

**`Format::JSON::_float_roundtrips` returns false, rather than croaking, when
the reparsed leaf is not a float:**

```perl
    return 0 unless File::SOPS::Encrypted->detect_type($back) eq 'float';
```

The `Math::BigFloat` carrier then writes the canonical decimal from
`value_to_bytes` — the same text the MAC digest covers — as a bare JSON
number, which is what the same leaf has always produced on the YAML side.

This follows k62 / ADR 0006: **where a representation exists, the emitter
writes it; a refusal is for a leaf that has none.** It also removes the
JSON/YAML asymmetry the refusal introduced, and it makes the most obvious
caller path — `my $v = extract(...); encrypt(data => { x => $v })` — produce a
correct document instead of an error.

### What was measured

A 244-row corpus (61 leaves × 2 slots × both handlers: the ADR 0005 and
ADR 0006 float cases, the int64 edges, strings, booleans, `undef`, leaves taken
out of a YAML parse, and the dualvar shapes) through
`Format::YAML->emit` and `Format::JSON->emit`, before and after:

- **20 rows move. All 20 are JSON, all 20 are this leaf class** — a float
  carrying a public PV. No YAML row moves, no ADR 0005 / ADR 0006 row moves, no
  int, string, boolean or `undef` row moves.
- For the k78 case itself the resulting document is **byte-identical** to
  the one a bare NV of the same value produces: both go through the carrier,
  both write `0.30000000000000004`.

End to end against sops 3.13.3, 14 float values, each written twice into an
`_unencrypted` JSON slot — once as a bare NV, once as the ADR 0010 dualvar —
and read back with `sops -d`:

- **28 of 28 documents: exit 0, value read back as a number, same double.**
- 8 of the 14 values produce byte-identical documents either way (the
  17-digit and 16-digit carriers, `-0.0`, `0.0`, `1.5`, `2.0`, `DBL_MAX`,
  `DBL_MIN`).
- 6 differ in **spelling** only — `1e-7`, `1e-20`, `5e-324`, `1e20`, `1e29`,
  `1e300`, where the bare NV survives Cpanel's `%.15g` and so keeps its
  exponent notation, while the dualvar's canonical text is positional
  (`0.0000001`, 301 digits, …). Both spellings are the same double, both exit
  0, and `sops -d` prints the same number for both. The identical six rows
  already differ this way on the **YAML** side today, unchanged by this ADR —
  it is ADR 0010's "the spelling is the wire's" table, not a new effect.

## Consequences

### Wire bytes that move

Only for a JSON leaf that is a float carrying its own public string form, and
only relative to 89ed194 — which wrote no bytes at all for it, it died. Against
the last release the same leaf changes from a **quoted string** to a **bare
number**, which is the defect k78 reported.

Nothing else moves: measured over the corpus above, and pinned by
`t/24-float-precision.t` section 14, which byte-asserts the ADR 0005 / ADR 0006
JSON output.

### What changes for existing callers

| input | before 89ed194 | at 89ed194 | now |
|---|---|---|---|
| `extract`ed float into an unencrypted JSON slot | `"0.3000…4"` (string) | croak | `0.3000…4` (number) |
| YAML-parsed float re-emitted as JSON | quoted string | croak | bare number |
| the same leaf in an **encrypted** slot | works | works | works |
| the same leaf in **YAML** | works | works | works |
| a float that was merely printed | unaffected | unaffected | unaffected |

A caller who relied on the croak as a validity check loses it. Nothing that
produced a correct document stops doing so, and no document that could be read
before becomes unreadable.

### The string half is discarded where it disagrees

`dualvar(1.5, 'banana')` now writes `1.5` in JSON. That is what the **YAML**
carrier has done since ADR 0006 (measured, unchanged: the document holds `1.5`
and `sops -d` exits 0), so the two handlers now agree, but the disagreement
between the halves is resolved silently in favour of the number. For an
**integer** leaf of the same shape the answer is the opposite — ADR 0012
refuses it — and that asymmetry is deliberate, decided in k85 and argued
in full below.

### Why a contradicting float string half is repaired, where an integer's is refused (k85)

`dualvar(1.5, 'banana')` is written as `1.5`. `dualvar(5, 'five')` is refused
(ADR 0012). Two leaves of one shape, two opposite answers, and the question the
ticket asked was whether that is a defect. It is not, for two reasons, and the
second is the one that settles it.

**For a float the walk already owns the rendering; for an integer it does not.**
`value_to_bytes` writes a double as Go's `strconv.FormatFloat(v, 'f', -1, 64)` —
the shortest decimal that round-trips, up to 17 significant digits — while every
emitter in this distribution renders one with 15. ADR 0006 exists because of
that gap: since then the walk decides, per float leaf, whether the emitter's own
output parses back to the same double, and substitutes a carrier holding the
canonical decimal where it does not. There is therefore no state in which "the
caller's text is what gets written" for a float. Writing `1.5` for
`dualvar(1.5, 'banana')` is that mechanism doing what it does for every float —
not a new decision about which half the caller meant.

An integer has no such gap. `strconv.Itoa` and Perl's own rendering of an IV
agree exactly, both emitters write the canonical decimal straight from the
number, and the walk has no reason to stand between them. So for an integer,
picking the number **is** a new intervention, and the only thing it can be based
on is a guess.

**And the decisive one: the two refusals do not cost the same.** ADR 0012's rule
refuses nothing that worked — every one of its fourteen newly refused documents
failed its own MAC before it, measured, `sops -d` exit 51. A refusal here would
refuse documents that are **correct today**, and 89ed194 is what that looks
like: it refused this class and had to be undone, which is what this ADR did.

Measured against sops 3.13.3, leaf under `_unencrypted`, one document per row:

| leaf | YAML document | `sops -d` | JSON document | `sops -d` |
|---|---|---|---|---|
| `dualvar(1.5, '1.5')` | `1.5` | exit 0 | `1.5` | exit 0 |
| `dualvar(1.5, 'banana')` | `1.5` | exit 0 | `1.5` | exit 0 |
| `1.50` from a YAML parse | `1.50` | exit 0 | `1.5` | exit 0 |
| `0.50` from a YAML parse | `0.50` | exit 0 | `0.5` | exit 0 |
| `2.0` from a YAML parse | `2.0` | exit 0 | `2` | exit 0 |
| any of them in an encrypted slot | `ENC[…]` | exit 0 | `ENC[…]` | exit 0 |

The three middle rows are the ones that decide it: they carry no dualvar and no
contradiction, only a spelling a YAML parser kept, and the string comparison
that would catch `banana` catches every one of them too. Every row states the
number the digest covers — `1.50` and `2.0` are the same double as `1.5` and
`2`, which is the whole of ADR 0006's rule — and sops reads all of them. Nothing
is broken, so a refusal would be a behaviour change against working files.

What is lost is the string half, in the one case where it contradicts the
number, and no `type:float` leaf could have carried it anyway: a SOPS float is a
double, and the only text it can hold is that double's canonical decimal.

The rule that comes out of the pair, and the one to apply to the next leaf class
that raises it: **repair where the walk is already the author of the text and
the alternative would refuse a correct document; refuse where writing anything
at all means choosing between two things the caller might have meant.** ADR 0012
states the same boundary from the integer side.

## Rejected alternatives

**Keep the refusal (89ed194).** It is a guard whose stated reason — "the
value's TYPE changed between what the caller handed in and what the document
states" — is answered by writing the number, not by refusing to write anything.
Measured, it also refuses every YAML-parsed float on the way into JSON, which
is a document this distribution has always written correctly in the other
format.

**Hand the emitter a PV-stripped copy** (`0 + $value`) at the leaf. It reaches
the same document — the stripped NV then fails the round-trip check on its own
merits for a 16/17-digit value and goes to the carrier anyway — through a
second mechanism that would have to be kept in step with the first. The
carrier is already the one place where a canonical decimal becomes JSON bytes;
`return 0` routes to it and adds nothing.

**Refuse only when the string half contradicts the number**, repairing the
`extract` case and refusing `dualvar(1.5, 'banana')`. It cannot be decided by
measurement: telling the two apart means numifying the string half, and
`dualvar(0, 'zero')` numifies to `0`, which is exactly the value it would be
compared against. Pattern-matching a value's text is what ADR 0002 removed.
Raised as k85 and **decided there against.** One test does not need
numifying — comparing the PV against `value_to_bytes` as a string — but what it
selects is every PV that is not already the canonical decimal, which is
`banana` and `1.50` and `0.50` and `2.0` alike: a contradiction and three
spellings that come straight out of an ordinary YAML parse and produce correct
documents today, `sops -d` exit 0 in both formats (measured). So the choice is
not between refusing a contradiction and repairing it; it is between repairing
all four and refusing all four. See
"Why a contradicting float string half is repaired, where an integer's is
refused" above. The refusal that costs nothing is ADR 0012's.
