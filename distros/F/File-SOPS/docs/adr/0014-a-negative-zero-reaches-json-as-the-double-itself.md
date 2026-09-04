# ADR 0014 — A negative zero reaches JSON as the double itself, not as a Math::BigFloat

- Status: accepted
- Date: 2026-08-20
- Tags: float, json, wire-format, interop
- Resolves k88
- Depends on ADR 0005 (why this handler binds `Cpanel::JSON::XS` by name, and
  the `-0.0` it writes that no other backend does), ADR 0006 (the
  `roundtrips`/`carrier` pair, the rule that an emitted decimal has to parse
  back to the same double, and k62's amendment that made the YAML carrier
  write `-0.0`) and ADR 0011 (which sends a PV-carrying float leaf to the
  carrier instead of refusing it)

## Context

`File::SOPS::Format::JSON::_float_carrier` puts a canonical decimal into a JSON
document as a bare number, and `Math::BigFloat` is the only carrier measured to
survive `Cpanel::JSON::XS` unquoted. It has no signed zero:
`Math::BigFloat->new('-0', undef, undef)` stringifies as `0`. So for one leaf
class the carrier's own assertion — which exists to catch a decimal
`Math::BigFloat` truncated — fired on a **sign** it cannot carry, and said so in
a message about a global `accuracy` or `precision` setting that was never in
play:

```
Math::BigFloat did not render a float leaf at full precision.
Check for a global Math::BigFloat->accuracy or ->precision setting.
```

The route in is ordinary caller code, not a contrivance: **read a YAML file,
write it as JSON.** `YAML::XS` keeps the source text of every scalar it parses,
so a document containing `-0.0` yields a float leaf with a public PV of `-0.0`;
`Cpanel::JSON::XS` writes a PV-carrying scalar as a quoted string when that PV
differs from its own rendering of the number, so `_float_roundtrips` answers no
(ADR 0011) and the leaf goes to the carrier — which died. Measured, one document
per row, unencrypted leaf, sops 3.13.3:

| leaf | to JSON | to YAML |
|---|---|---|
| bare NV `-0.0` | `-0.0`, `sops -d` exit 0, reads `-0` | `-0.0`, exit 0 |
| `-0.0` from a YAML parse | **croak** | `-0.0`, exit 0 |

One cell of four. The same value written from a bare NV goes through fine,
because it never reaches the carrier at all: Cpanel renders it `-0.0` on its
own, the round-trip check says yes, and the leaf is left alone.

`Math::BigFloat` mangles nothing else. Measured over 2018 canonical texts from
`value_to_bytes` — the ADR 0005/0006 float corpus plus 2000 random doubles
spanning `1e-20` to `1e20` — **`-0` is the only one it does not reproduce.**

## Decision

**Where the canonical text is `-0`, the JSON carrier is the double itself,
stripped of the string half that sent it there:**

```perl
    my $carrier = $text eq '-0' ? unpack('d', pack('d', $value))
                                : Math::BigFloat->new($text, undef, undef);
```

`Cpanel::JSON::XS` writes that bare NV as `-0.0` — the bytes the same value has
always produced when it arrived without a PV — and that text parses back to the
same double, which is what ADR 0006 asks of an emitted decimal, not that it be
spelled canonically. It is the same split k62 measured on the YAML side,
in the other format. Measured, sops 3.13.3, JSON leaf whose digest is `-0`:

| document holds | `sops -d` |
|---|---|
| `-0.0` | **exit 0**, reads back `-0` |
| `-0` (the canonical text) | exit 51, MAC mismatch — Go reads a JSON `-0` as an **integer** and digests `0` |

So JSON is not the easy case ADR 0006 assumed when it wrote "JSON has no such
problem: `-0` is a valid JSON number". It is a valid JSON number and it is the
one spelling that breaks the file, exactly as in YAML.

### The copy has to be pack/unpack, and this is the load-bearing part

No arithmetic route works. Measured on a `-0.0` leaf out of a YAML parse, the
same leaf three times in one process:

| copy | round 1 | round 2 | round 3 |
|---|---|---|---|
| `0 + $v` | `-0` | `0` | `0` |
| `$v * 1` | `-0` | `0` | `0` |
| `$v * 1.0` | `0` | `0` | `0` |
| `$v - 0.0` | `0` | `0` | `0` |
| `unpack('d', pack('d', $v))` | `-0` | `-0` | `-0` |

Two mechanisms, and the second is why this table is in an ADR rather than in a
comment. IEEE-754 makes `-0.0 + 0.0` a **positive** zero, so adding zero drops
the sign outright — the same fact ADR 0006 already records for Perl's
`grok_number`. And Perl's arithmetic ops call `SvIV_please` on their operands,
which sets the **private** `IOK` on the *caller's* scalar **in place**; the next
multiplication of that leaf then takes the integer path and returns a plain `0`.
That is k72 and k73 one frame further in, on a value the walk was handed
rather than one it read: the first document written in a process would have been
correct and every later one silently wrong, from the same tree. `pack 'd'` reads
the NV and nothing else.

The private `IOK` it leaves behind does not change the leaf's type —
`detect_type` reads the **public** flag (ADR 0002), which is the whole reason
that rule exists — but it does change what a later multiplication returns.

### The assertion stays, and is asked through `value_to_bytes`

It caught the `* 1` version of this change during measurement, which is the
argument for keeping it. It now compares
`File::SOPS::Encrypted->value_to_bytes($carrier)` against the text rather than
stringifying the carrier, so it means what the digest means for both branches,
and its message names both causes instead of one that may not apply. It carries
no value: that is the plaintext.

### What was measured

The 228-row emitter corpus (57 leaves × 2 shapes × both handlers: the ADR
0005/0006 floats, floats and integers out of a YAML parse, the ADR 0010
dualvars, int64 edges, strings, booleans, `undef`, arrays and nested hashes),
before and after:

- **6 rows move. All 6 are JSON, and all 6 were a croak.** No row that produced
  a document produces different bytes, in either format.
- The 6 are the three leaves whose canonical text is `-0` and that carry a
  public PV — `-0.0` and `-0.00` out of a YAML parse, and an array containing
  one — in both document shapes.

End to end against sops 3.13.3, each source written into both an encrypted and
an unencrypted slot, in both formats, and the same source repeated a second time
in the same process:

- **6 of 6 documents: `sops -d` exit 0**, both leaves read back as `-0`.
- 6 of 6 verify against their own MAC here.
- The repeated round produces byte-identical output, which is the check the
  `* 1` version failed.

## Consequences

### Wire bytes that move

None. Every document this changes was previously not written at all — the
emitter died. A JSON leaf whose digest is `-0` now reaches the file as `-0.0`,
which is byte-identical to what a bare NV of the same value has always produced.

### What changes for existing callers

| input | before | now |
|---|---|---|
| `-0.0` from a YAML parse, written as JSON | croak, wrong cause | `-0.0`, `sops -d` exit 0 |
| any tree containing one, written as JSON | croak | written |
| a bare NV `-0.0` written as JSON | `-0.0` | `-0.0` (untouched) |
| the same leaf in YAML | `-0.0` | `-0.0` (untouched) |
| every other float, either format | unchanged | unchanged |

A caller who was relying on the croak was relying on an error that named the
wrong cause for a document this distribution can write.

### The message no longer lies, and no longer fits on one line

The remaining assertion covers two carriers, so it names two causes. It is
reachable only if `Math::BigFloat` truncates despite the explicit
`undef, undef`, or if a build's `pack 'd'` round trip drops a signed zero.

### Not fixed here

The carrier callback is given `($value, $text)` and no key path, so this message
— unlike the reject callbacks' since k68 — cannot name the leaf it died on.
Widening `canonical_float_tree`'s carrier contract is a change to every handler
and was left out of this one. k68's known gap, recorded in `Changes`.

## Rejected alternatives

**Leave the repair out and fix only the message.** The ticket allowed it, and it
is the smaller change. It is also the wrong one by this repository's own
precedent: k62 measured a YAML spelling that works rather than accepting
that `-0` had none, and ADR 0011 chose the carrier over a refusal for the leaf
class that leads straight into this one. A spelling that works exists here too,
and it is the one the same value already produces through the other door.

**Make `_float_roundtrips` answer yes for this leaf.** It answers no for a real
reason — Cpanel writes the PV-carrying scalar as a quoted **string**, and the
reparse proves it. Overriding the measurement to route around a broken carrier
would put the string `-0.0` in the document under a digest of `-0`.

**Hand the emitter a PV-stripped copy for every float** rather than only for
`-0`. ADR 0011 rejected this as a second mechanism beside the carrier, and the
measurement agrees: the stripped copy of `0.0` renders as `0.0` where the
carrier writes `0`, so it moves bytes for leaves that work today. The narrow
branch moves none.

**`Math::BigFloat->new('-0')` with the sign restored afterwards** (`->bneg`, or
a subclass that models a signed zero). `allow_bignum` matches the class name
exactly and refuses a subclass, and a `Math::BigFloat` that stringifies as `-0`
would put the canonical text into the document — which is the spelling measured
above at `sops -d` exit 51.
