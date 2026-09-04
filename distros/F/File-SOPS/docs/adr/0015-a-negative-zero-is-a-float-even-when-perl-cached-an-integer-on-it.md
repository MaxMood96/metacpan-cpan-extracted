# ADR 0015 — A negative zero is a float even when Perl has cached an integer on it

- Status: accepted
- Date: 2026-08-20
- Tags: float, yaml, wire-format, type-detection, interop
- Resolves k89
- Amends ADR 0002 (the type ladder gains its one exception) and ADR 0013 (the
  Go model's float conversion, which lost the same sign one level down)
- Depends on ADR 0006 and its k62 amendment (the emitted decimal has to
  parse back to the same double, which is why a negative zero is written `-0.0`
  and not `-0`) and ADR 0014 (`pack`/`unpack` is the only copy of a double that
  keeps the sign of a zero, in every round)

## Context

`File::SOPS::Encrypted::_sv_kind` reads the SV's public `IOK` before its public
`NOK`, and everything in this layer is downstream of that: `detect_type` labels
the wire, `value_to_bytes` derives the digest, `canonical_float_tree` picks the
branch, `assert_representable` picks the check. ADR 0002 put it there and the
reason still holds — the type comes from the scalar, never from a pattern on its
text.

Perl caches an `IV` on an `NV` whenever `(NV)(IV)nv == nv`, and sets the
**public** `IOK` when it does. For a **negative zero** that test passes and the
sign does not survive the cast: the cached `IV` is `0`, which is a different
value from `-0.0` — different bits, a different `strconv.FormatFloat`, a
different digest. So the SV publishes two halves that disagree, and `_sv_kind`
was taking the one that had already lost the information.

`YAML::XS` is where such a scalar comes from in practice. It caches the `IV` for
an integral float in **exponent** notation and not otherwise, measured, one
`Load` per row:

| source | `SVf_IOK` | `SVf_NOK` | this library | digest |
|---|---|---|---|---|
| `-0.0` | | ✓ | `float` | `-0` |
| `-0.00` | | ✓ | `float` | `-0` |
| `-0.5e0` | | ✓ | `float` | `-0.5` |
| `-0.0e0` | ✓ | ✓ | **`int`** | **`0`** |
| `-0e0` | ✓ | ✓ | **`int`** | **`0`** |
| `1.0e0` / `1e3` / `0755e0` | ✓ | ✓ | `int` | `1` / `1000` / `755` |

Every row but the negative zeroes agrees with Go anyway — `1e3` is a float to
`yaml.v3` and `strconv.FormatFloat` writes it `1000`, which is what
`strconv.Itoa` writes too. ADR 0013 measured that and accepted it. The negative
zero is the one value where the two labels produce **different bytes**.

Measured against sops 3.13.3, leaf under `_unencrypted`, one document per row,
at 02afc79:

| source | our type | our digest | document | `sops -d` |
|---|---|---|---|---|
| `-0.0e0` | `int` | `0` | `-0.0e0` | **exit 51** |
| `-0e0` | `int` | `0` | `-0e0` | **exit 51** |
| `-0.0E+0` | `int` | `0` | `-0.0E+0` | **exit 51** |
| `-0.000e2` | `int` | `0` | `-0.000e2` | **exit 51** |
| `-0.0e-5` | `int` | `0` | `-0.0e-5` | **exit 51** |
| `-0e-0` / `-0.0e+0` / `-00.0e0` / `-0.e0` / `-.0e0` | `int` | `0` | as written | **exit 51** |
| `-0.0` / `-0.00` | `float` | `-0` | `-0.0` / `-0.00` | exit 0, reads `-0` |
| `-0.5e0` | `float` | `-0.5` | `-0.5e0` | exit 0 |
| `0.0e0` | `int` | `0` | `0.0e0` | exit 0 |
| `-1.0e0` | `int` | `-1` | `-1.0e0` | exit 0 |

### It is not a YAML spelling, it is any negative zero a caller has touched

The exponent notation is how `YAML::XS` gets there; it is not the only door, and
this is what decides the shape of the fix. Perl sets the same cache from
**ordinary numeric use of the caller's own scalar**, in place. Measured on a bare
`my $v = -0.0`, at 02afc79:

| what the caller did first | flags after | this library | digest |
|---|---|---|---|
| nothing | `NOK` | `float` | `-0` |
| `$v == 0` | `IOK` `NOK` | **`int`** | **`0`** |
| `$v > 1` | `IOK` `NOK` | **`int`** | **`0`** |
| `int($v)` | `IOK` `NOK` | **`int`** | **`0`** |
| `$v + 0` | `IOK` `NOK` | **`int`** | **`0`** |
| `sprintf('%d', $v)` | `IOK` `NOK` | **`int`** | **`0`** |
| `"$v"` | `NOK` | `float` | `-0` |

This is ADR 0002's own contamination note — "a caller's `$h{port} > 1024`
retypes the document" — landing on the one value where the retyping also changes
the **bytes**. `if ($ratio == 0)` before encrypting turned a `-0` into a `0` in
the document, silently, and whether it did depended on whether the caller had
looked at the value. k32 in a different frame.

### Why the k86 guard waved it through, which is the interesting part

ADR 0013's `Format::YAML::_go_scalar_bytes` models `yaml.v3` and exists to catch
exactly a document that disagrees with its own MAC. It answered `0` for
`-0.0e0` — the same wrong answer we had — so the leaf agreed with the model and
was written.

The model derived the float through `value_to_bytes($p * 1.0)`. That is the
conversion ADR 0014 measured one level down and rejected. Measured, the same
scalar three times in one process:

| copy of the token `-0.0e0` | round 1 | round 2 | round 3 |
|---|---|---|---|
| `$p * 1.0` | `0` | `0` | `0` |
| `$p * 1` | `0` | `0` | `0` |
| `0 + $p` | `0` | `0` | `0` |
| `$p - 0.0` | `0` | `0` | `0` |
| `unpack('d', pack('d', $p))` | `-0` | `-0` | `-0` |

Without an exponent, `-0.0` survives `* 1.0` as an `NV` and the model answered
`-0`, which is why the guard is right for `-0.0` and why this went unseen for a
release. The comment above `_go_float` already warned about this mechanism in
so many words; the implementation had it anyway.

### What sops does with the same value

Measured, because it decides whether the honest answer is a repair or a refusal.

```
$ printf 'x_unencrypted: -0.0\n' > plain.yaml && sops -e --age … plain.yaml
x_unencrypted: -0
$ sops -d …
MAC mismatch. …
exit 51
```

**sops cannot write an unencrypted negative zero either.** It resolves the value
to the float `-0`, writes the canonical text `-0`, and then re-reads that as an
*integer* and rejects its own file. Every exponent spelling above does the same.
So unlike ADR 0013's `mode: 0755`, there is no "pass what sops itself writes"
here — what sops writes is broken, and `-0.0` is the only spelling both
implementations read as the double the digest covers. That is k62's finding
and it is unchanged.

In an **encrypted** slot sops is self-consistent and unambiguous:

```
$ printf 'y: -0.0e0\n' | sops -e … ;  y: ENC[…,type:float]
$ sops -d … ;                          "y": -0
```

`type:float`, plaintext `-0`. Which is exactly what this ADR makes this library
write.

## Decision

**A scalar whose public `NOK` half is a negative zero is a `float`, whatever its
public `IOK` says. And the Go model derives its float with `pack`/`unpack`, like
every other copy of a double in this distribution.**

```perl
my $NEGATIVE_ZERO_BITS = pack('d', -0.0);

sub _sv_kind {
    my $sv    = B::svref_2object(\$_[0]);
    my $flags = $sv->FLAGS;
    if ($flags & B::SVf_IOK()) {
        return 'float'
            if ($flags & B::SVf_NOK())
            && pack('d', $sv->NV) eq $NEGATIVE_ZERO_BITS;
        return 'int';
    }
    return 'float' if $flags & B::SVf_NOK();
    return 'str';
}
```

```perl
sub _go_float {
    my ($p) = @_;
    my $bytes = File::SOPS::Encrypted->value_to_bytes(unpack('d', pack('d', $p)));
    …
}
```

Both are needed and they fix different things — measured, see below. The first
fixes the **type and the digest**; the second keeps the guard from refusing the
now-correct leaf, because the model would otherwise still answer `0` where we
answer `-0`.

Nothing else changes. The `-0.0e0` document keeps the bytes it has: `YAML::XS`
retains the source text of every scalar it parses and writes it back verbatim,
`_float_roundtrips` reparses that and gets the same `-0` out, so the leaf never
reaches the carrier. In JSON the leaf now takes the float branch and ADR 0014's
carrier writes `-0.0`, which is what a negative zero has been written as there
since k88.

### Why this is still the SV deciding, and not a pattern

ADR 0002's rule is that the type comes from the scalar. It still does. The NV is
read **only where it is already public**, so nothing is numified into existence
and no flag is set by asking: `B::svref_2object(\$_[0])->NV` on a scalar that
already publishes `SVf_NOK` reads the slot that flag guarantees. No text is
looked at, in either direction — not the leaf's PV, not its stringification.

What changed is narrower than the ladder: the ladder assumed the two public
halves of a scalar cannot contradict each other, and for one value they can. The
same shape as ADR 0011 and ADR 0012, which handle a number whose **string** half
contradicts it; this is a number whose **integer** half contradicts it, and the
comparison is on bits rather than on text because that is what the halves are.

### What was measured

A 324-row emitter corpus — 81 leaves × 2 slots (`x_unencrypted`, `x`) × both
handlers — each row encrypted, the document handed to `sops -d`, and the same
document verified against its own MAC here. The leaves are the ten negative-zero
exponent spellings, their positive counterparts, the non-exponent negative
zeroes, the exponent neighbours (`1e3`, `1E3`, `1e+3`, `0755e0`, `1e20`, `1e-3`,
`-1.0e0`, `100.0e0`), plain YAML and JSON numbers, the ADR 0005/0006/0010/0011
float cases, the int64 edges, dualvars, booleans, `undef`, an empty string, a
non-ASCII string, a `-0.0` a caller compared or `int()`ed first, an array and a
nested hash. Before and after, row for row:

- **260 rows are byte-identical**, same `sops -d` exit code, same value read
  back — `1e3`, `1.0e0`, `0755e0`, `0.0e0`, `-1.0e0`, `-0.0`, `-0.5e0`, `007`,
  `5432`, `0.1`, `1e20`, `1e-7`, `9007199254740993`, `-9223372036854775808`,
  the dualvars, the booleans and the strings included.
- **64 rows move, and every one of them holds a negative zero.** No other leaf
  in the corpus changes in any way.
  - **12 were `sops -d` exit 51** (YAML, unencrypted slot) and are now exit 0,
    read back as `-0`.
  - **12 were a croak** (JSON, unencrypted slot — ADR 0012's guard fired on a
    leaf it typed `int` with a contradicting PV) and are now written as `-0.0`,
    exit 0, read back as `-0`.
  - **40 produced a readable document before and still do, with different
    bytes**: the encrypted slots, where `type:int` plaintext `0` becomes
    `type:float` plaintext `-0` and `sops -d` reads `-0` where it read `0`; and
    the caller-touched bare `-0.0`, which was written as `0` (YAML) or as `-0`
    read as an integer (JSON) and is now written `-0.0` in both.
- **0 rows that worked stop working.** 281 rows produced a `sops -d`-readable,
  self-verifying document before; 305 do now; the 281 are a subset of the 305.
- Three encrypt rounds of the **same tree in the same process**, for all ten
  spellings plus `-0.0`, `-0.5e0`, `1.0e0`, `1e3`, `0.0e0`, both formats: every
  round byte-identical, every `sops -d` exit 0, every value read back the same.
  This is the check ADR 0014's `* 1` version failed, and the reason `_go_float`
  is not `* 1.0` any more; `_go_scalar_bytes` on a reused token scalar is
  likewise stable over three rounds, for `-0.0e0`, `0755`, `1_000`, `.inf`,
  `2015-01-01` and the uint64 edge alike.
- The cost, per 1000 `detect_type` calls: an int, a string and an ordinary
  float are unchanged inside the noise (0.6–0.9ms either way); a scalar
  carrying **both** public flags — the only one that reaches the new branch —
  is **0.65ms → 1.0ms**, i.e. one `->NV` and one eight-byte `pack` for the
  leaves that have something to disagree about, and nothing for anything else.
- Counter-check, on `t/31`'s 13 subtests and 254 assertions: reverting
  `_sv_kind` alone fails **6 subtests and 55 assertions**; reverting `_go_float`
  alone fails **3 subtests and 20 assertions** — the ten spellings are written
  and then refused by the stale model; reverting both fails **7 subtests and 77
  assertions**. Each half is pinned on its own, which is the point of measuring
  them separately.

## Consequences

### Wire bytes that move

**Yes, for one value.** A leaf whose double is a negative zero and whose SV
carries Perl's integer cache used to be written as `type:int` / `0`; it is now
`type:float` / `-0`. 40 of the 324 corpus rows, all of them a negative zero,
and the new bytes are the ones sops itself produces for the same source
(measured: `sops -e` writes `type:float` and `sops -d` reads `-0`).

A caller who was relying on `-0.0` arriving as `0` was relying on a value that
changed under them depending on whether anything had compared it first.

### What changes for existing callers

| input | before | now |
|---|---|---|
| `-0.0e0` (and nine sibling spellings) from a YAML parse, unencrypted, YAML | written, `sops -d` **exit 51** | written, exit 0, reads `-0` |
| the same, unencrypted, JSON | **croak** ("integer leaf that carries its own string form") | written `-0.0`, exit 0, reads `-0` |
| the same, encrypted, either format | `type:int`, sops reads `0` | `type:float`, sops reads `-0` |
| a bare `-0.0` the caller compared or `int()`ed | `type:int`, written `0` | `type:float`, written `-0.0` |
| a bare `-0.0` the caller did not touch | `-0.0` | `-0.0` (untouched) |
| `1e3`, `1.0e0`, `0755e0`, `0.0e0`, `-1.0e0` and every other integral exponent | `type:int` | `type:int` (untouched) |
| every other leaf, either format | unchanged | unchanged |

### Reading is unaffected

`_sv_kind` runs on both sides, so the decrypt-side MAC walk types a document's
`-0.0e0` the same way it is now written. That is what makes the twelve YAML rows
verify: before this change the file verified against **our own** MAC (both sides
were wrong together) and failed against sops; now both sides say `-0`. A
`type:float` plaintext of `-0` already came back as a negative zero
(ADR 0009 / k72), so nothing on the decrypt path needed a second change.

### The model is a model, and it drifted

ADR 0013 said `_go_scalar_bytes` is "verified against the binary over the corpus
rather than trusted", and the corpus it was verified against had no negative
zero with an exponent in it. The failure mode is the specific one this
distribution ships against: **the model agreed with our own wrong answer**, so
the guard confirmed the defect instead of catching it. The lesson is recorded
rather than the guard weakened — a model of a foreign reader has to be measured
where it and this library could plausibly be wrong *together*, which is exactly
where a conversion is shared between them.

## Rejected alternatives

**Fix only `_go_float`, and let the guard refuse these documents.** The obvious
minimal change, and k89's own first suggestion. Measured on the same
corpus: **12 rows move and all 12 go from `sops -d` exit 51 to a croak.** It
fixes neither half of the defect — the twelve JSON rows still croak for the
wrong reason, the forty encrypted-slot rows still write `type:int` / `0`, and a
caller's compared `-0.0` still silently becomes `0`. It refuses a value sops
itself stores without complaint in an encrypted slot, and the refusal cannot
name anything to pass instead, because `-0` is what sops writes and `-0` is what
breaks. ADR 0013 refused `0755` on the strength of being able to say "pass 493,
that is what sops writes"; there is no such sentence here. The repository's own
precedent — k62, k78, k88 — is to write the spelling that works.

**Read `NOK` before `IOK`.** One line, no bit comparison, and it fixes every row
this ADR fixes. Measured: **114 rows move instead of 64**, and the extra 50 are
every integral exponent leaf in the corpus — `1e3`, `1E3`, `1e+3`, `1.0e0`,
`1e1`, `-1e1`, `100.0e0`, `0755e0`, `0.0e0`, `0e0`, `+0.0e0`, `0.000e2`,
`0.0e-5`, `-1.0e0` — retyped from `type:int` to `type:float`, plus a plain `2.0`
and a plain `0.0` that a caller happened to compare. Their digest bytes were
already right and their documents already worked; moving them is 50 rows of
unmeasured wire change to fix a value that is one row of it. It also sweeps in
Perl's boolean sentinels, which carry both flags and are a separate defect with
a separate answer (k90).

**Compare with `$nv == 0 && sprintf('%g', $nv) =~ /^-/`, or any numeric test.**
`==` cannot tell the two zeroes apart, which is the whole problem, and every
arithmetic form measured above sets the private `IOK` on its operand in place.
The bit pattern is the only thing that answers the question without asking Perl
to convert anything; `pack 'd'` reads the `NV` slot and nothing else, and the
constant it is compared against is built the same way, so it is endian-safe by
construction.

**Repair it in `value_to_bytes` alone, keeping `type:int`.** `type:int` with a
plaintext of `-0` is not a wire form: Go's `strconv.Atoi` reads it as `0` and
re-derives `strconv.Itoa(0)` = `0`, so the MAC breaks in the other direction —
and this library's own `_deserialize_value` refuses to read back a `type:int`
plaintext it cannot round-trip. The type label and the digest are one decision.

**Quote the leaf on the way out.** ADR 0013 rejected this for the same reason and
it is worse here: `-0.0e0` would become the string `"-0.0e0"`, a retyping of a
value both implementations agree is a number, to protect a digest that has a
working spelling already.

**Put the negative-zero test in `detect_type` rather than in `_sv_kind`.**
`value_to_bytes`, `assert_representable` and `canonical_float_tree` all call
`_sv_kind` directly and would keep the old answer — the label would say `float`
while the digest still said `0`. One ladder, one place, which is the rule
ADR 0002 established and the reason `_detect_type_for_mac` no longer exists.
