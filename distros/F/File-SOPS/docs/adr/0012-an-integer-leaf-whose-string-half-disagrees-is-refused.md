# ADR 0012 — An integer leaf whose string half disagrees with its number is refused

- Status: accepted
- Date: 2026-08-20
- Tags: int, mac, wire-format, guards, yaml, json, interop
- Resolves k84, and states from the integer side the asymmetry k85
  settled (the argument is in ADR 0011)
- Depends on ADR 0002 (the type comes from the SV's public flags, which is why
  such a leaf is an `int` and its digest is the number), ADR 0008 (the rule
  that a leaf an emitter cannot write as the text the digest covers is
  refused — this is the same rule, applied to a scalar instead of a reference)
  and ADR 0011 (the float leaf of the same shape, which is **repaired**; the
  asymmetry is argued below)

## Context

`detect_type` reads the public `SVf_IOK` first, so a scalar that is
numerically an integer and carries a string form of its own — a
`Scalar::Util::dualvar`, or a value a YAML parser kept the source spelling of —
is an `int`, and `value_to_bytes` derives the digest from the **number**. Both
emitters write the **string half**: `YAML::XS` bare, `Cpanel::JSON::XS` quoted
whenever that half differs from its own rendering of the number.

The document and its own MAC then state different things. Nothing catches it:
`Encrypted::_canonical_floats` only inspects a leaf whose SV kind is `float`,
so an int leaf reached neither the `roundtrips`/`carrier` pair nor the `reject`
callback, and `assert_representable` is about values no SOPS document can
carry at all.

Measured against sops 3.13.3, one document per row, leaf under
`_unencrypted`, before this change:

| leaf | digest | YAML document | `sops -d` | JSON document | `sops -d` |
|---|---|---|---|---|---|
| `dualvar(5, 'five')` | `5` | `five` | **exit 51** | `"five"` | **exit 51** |
| `dualvar(0, 'zero')` | `0` | `zero` | **exit 51** | `"zero"` | **exit 51** |
| `dualvar(5, '')` | `5` | `''` | **exit 51** | `""` | **exit 51** |
| `dualvar(0, 'notanumber')` | `0` | `notanumber` | **exit 51** | `"notanumber"` | **exit 51** |
| `007` from a YAML parse | `7` | `007` | exit 0 | `"007"` | **exit 51** |
| `+7` from a YAML parse | `7` | `+7` | exit 0 | `"+7"` | **exit 51** |
| `-0` from a YAML parse | `0` | `-0` | exit 0 | `"-0"` | **exit 51** |
| `1e3` from a YAML parse | `1000` | `1e3` | exit 0 | `"1e3"` | **exit 51** |
| `dualvar(7, '7')` | `7` | `7` | exit 0 | `7` | exit 0 |

Two things that table settles, and neither was assumed:

- **It is not only a caller-built dualvar.** `YAML::XS` retains the source text
  of every scalar it parses, so `007`, `+7`, `-0` and `1e3` all arrive carrying
  a public PV that differs from the canonical decimal. In YAML they are written
  back exactly as they came and Go reads the same number the digest covers, so
  those documents are correct. In JSON they are quoted and the file fails its
  own MAC. A caller who parses a YAML file and encrypts it as JSON hits this
  without ever having heard of a dualvar.
- **Which emitter breaks is a property of the emitter, not of the leaf.** Only
  the emitter can say whether it survives; that is what `roundtrips` already
  measures for floats.

The defect is strictly worse than k78's: there the document verified and
only the value's *type* had changed. Here the file is unreadable to sops and to
this library alike, and it is written silently.

## Decision

**At emit time, an integer leaf that carries its own, different string form is
asked of the emitter, and refused when the emitter does not write it as the
text the digest covers.**

In `Encrypted::_canonical_floats`, next to the float branch:

```perl
if ($kind eq 'int' && _has_public_pv($node)
    && "$node" ne __PACKAGE__->value_to_bytes($node)) {
    croak _leaf_location($path) . ": cannot write an integer leaf that "
        . "carries its own, different string form ..."
        unless $roundtrips->($node, __PACKAGE__->value_to_bytes($node));
    return $node;
}
```

- **The emitter answers, through the callback that already exists.**
  `Format::YAML::_float_roundtrips` compares `value_to_bytes` on both sides of
  a real `Dump`/`Load`; `Format::JSON::_float_roundtrips` does the same through
  the real encoder and decoder, and its type check — added for k78 as a
  hard-coded `eq 'float'` — becomes `eq detect_type($value)`, which is the same
  question for a float and the right one for an int. Nothing models what an
  emitter will do with a leaf.
- **Two cheap gates before the emitter is asked**, both facts about the leaf
  rather than models: it must carry a **public** PV, and that PV must **differ**
  from the digest's text. A leaf whose halves say the same thing has no
  disagreement to resolve. This is measurable cost, not decoration: every int in
  a YAML-parsed tree carries a PV, and asking the emitter about each of them
  costs 11ms → 38ms per 1000 leaves in YAML and 2ms → 10ms in JSON, against
  11ms → 14ms and 2ms → 5ms with the gate. The refusals are identical either
  way, measured over the corpus below.
- **The public `SVf_POK`, never the private `SVp_POK`** — the same rule
  `_sv_kind` follows for `IOK`/`NOK` and for the same reason: measured,
  `my $s = "$i"`, `$i eq ''` and `length($i)` set only the private flag, so a
  caller who logged or compared the value is not refused.
- **Emit time, not `assert_representable`.** The same argument ADR 0008 made
  and measured again here: the identical dualvar in an **encrypted** slot works
  today in both formats — it becomes `ENC[…,type:int]` whose plaintext is the
  number the digest covers, `sops -d` exit 0 — and a rule in
  `assert_representable` would refuse those documents and, since that method
  runs over every leaf on the encrypt path, refuse documents this library
  writes correctly.
- **The message names the key path and neither half of the value.** Keys are
  readable in a SOPS document by design; a plaintext value in an error message
  is a plaintext value in a bug report.

### Why refused, where ADR 0011 repairs

A repair is *available* — writing `0 + $value` produces a document that agrees
with the digest — so availability is not the question. What the repair costs
is:

- For `dualvar(5, 'five')` it silently stores `5` and destroys `five`. The
  contradicting half is often the meaningful one (`$!` is exactly this shape:
  numerically `errno`, as text the message).
- For `007` from a YAML parse it silently stores `7`, which loses nothing but a
  spelling — JSON cannot express `007` as a number at all.

**Nothing measurable separates those two cases.** Telling a spelling from a
contradiction means numifying the string half, and `dualvar(0, 'zero')`
numifies to `0` — the very number it would be compared against. Pattern-matching
a value's text is what ADR 0002 removed, and a guard that guesses wrong here
writes a document silently missing the half the caller meant.

So the leaf is named rather than written, and the caller says which half they
meant in one expression: `0 + $value` or `"$value"`. Both are in the message.

The float leaf of the same shape is repaired instead (ADR 0011), and that is
not the same case. The full argument is in ADR 0011, under "Why a contradicting
float string half is repaired, where an integer's is refused"; the two halves of
it, from this side:

**No emitter here can spell a double's canonical decimal on its own**, which is
why the walk already owns every float's rendering (ADR 0006). Writing `1.5` for
`dualvar(1.5, 'banana')` is that mechanism doing what it does for every float,
not a fresh choice between the halves. For an integer both emitters render the
canonical decimal from the number themselves, and the walk has no reason to be
in the way — so overriding a caller's string half there would be a new
intervention with nothing but a guess behind it.

**And the two refusals do not cost the same.** Every document this rule refuses
failed its own MAC before it — fourteen of fourteen, `sops -d` exit 51. A
refusal on the float side would refuse documents that are correct today:
measured against sops 3.13.3, `dualvar(1.5, 'banana')` writes `1.5` and exits 0
in YAML and in JSON, and the YAML column has read that way since ADR 0006. That
is the line between the two answers, and it is the same line this distribution
draws everywhere else: a guard may refuse a broken document, never a working
one.

Decided in k85, which asked whether the asymmetry was a defect. It is not,
and both ADRs now say so.

### What was measured

- The 244-row emitter corpus from ADR 0011 (61 leaves × 2 slots × both
  handlers), before and after: **28 rows move — 20 JSON, 8 YAML — and every one
  is this leaf class.** No float row, no string, boolean, `undef`, plain-int or
  int64-edge row, and no YAML row for `007`, `+7`, `-0`, `1e3` or
  `dualvar(7, '007')`, which YAML still writes exactly as it did.
- Every newly refused leaf, run end to end against sops 3.13.3 on the code as
  it stood **before** the guard: **14 of 14 exit 51, MAC mismatch.** Every leaf
  that was accepted before is still accepted, byte for byte, and still exits 0.
- `prove -lr t/` 679/679 before the new test file, unchanged by the guard: no
  existing document in the suite carries such a leaf.

## Consequences

- **A croak where a document used to be written.** A behaviour change, and it
  belongs in `Changes` as one — but nothing that worked stops working: every
  input that now croaks produced a file that failed its own MAC in the format
  it was written in, measured, exit 51.
- **The two formats refuse different sets, and that is the point.** YAML refuses
  only a leaf whose string half contradicts the number; JSON refuses those and
  every leaf whose PV is a different *spelling* of it, because Cpanel quotes it
  and JSON has no `007`. The rule is one rule — "what this emitter writes has
  to be what the digest covers" — asked of two emitters.
- **A caller converting a YAML tree to JSON now hears about it.** That is the
  widest-reaching consequence: `encrypt(data => YAML::XS::Load(...), format =>
  'json')` croaks for an int written as `007`, `+7`, `-0` or `1e3`, where it
  used to write a file `sops -d` rejects with exit 51.
- **Encrypted slots, plaintext emitters and decrypted trees are untouched.** An
  encrypted leaf is an `ENC[…]` string before the emitter sees it;
  `_deserialize_value` builds an int with `IOK` and no `POK` (measured), so
  nothing this library decrypts can trip the guard on the way back out.
- The `roundtrips` callback is no longer float-only. Its POD says so, and both
  handlers' `emit` POD names the new refusal.

### What changes for existing callers

Nothing for a tree of plain Perl scalars, hashes, arrays, booleans and `undef`
— which is every tree this library produces itself. A caller who passed a
dualvar, or a scalar straight out of a YAML parse into the *other* format, gets
an error naming the leaf's key path instead of a file nothing can read.

## Rejected alternatives

**Repair by writing the number** (`0 + $value`). It is one line, it makes every
one of the fourteen documents above verify, and it is what ADR 0011 does for a
float. It silently discards the string half in the one case where that half is
the value the caller meant, and no measurement distinguishes that case from the
harmless one. See above.

**Repair by digesting the string** — call such a leaf a `str` so the digest
covers the text the emitter writes. It moves the wire bytes of a leaf class
`detect_type` has typed by the SV since ADR 0002, re-introduces a second type
ladder for one shape of scalar, and picks the *other* half by guess.

**Refuse in `assert_representable`, next to the int64 and ref guards.** Format
-blind and earlier, and measured to be wrong for the same reason ADR 0008 gave:
the same leaf in an encrypted slot works in both formats today and must keep
working.

**Refuse every int leaf carrying a public PV, without asking the emitter.**
Simple, and it refuses `007`, `+7`, `-0` and `1e3` in **YAML**, where they are
written back exactly as they arrived and `sops -d` exits 0 — documents this
library reads and writes correctly today, including ones sops itself wrote.

**Extend the check to `str` leaves too.** A string's `value_to_bytes` is its own
text, so the document and the digest cannot disagree about it, and the check
would cost an emit-and-reparse for every string in every document. The open
question k84 raised — a `str` leaf whose emitted form differs from its PV
— is a *type* change at worst, not a MAC break, and stays where it was filed.
