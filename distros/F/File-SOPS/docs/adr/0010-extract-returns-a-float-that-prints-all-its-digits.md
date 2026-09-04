# ADR 0010 — `extract` returns a float that prints all of its digits

- Status: accepted
- Date: 2026-08-20
- Tags: float, api, json, yaml, interop
- Resolves k61 (second half; the first half needed no code, see ADR 0006)
- Depends on ADR 0006 (the canonical decimal and why the emitters could not
  write it) and ADR 0009 (the decrypted float's SV, which is the numeric half
  of what this returns)

## Context

`File::SOPS->extract` hands the caller the Perl scalar it found at the path.
For an **encrypted** float that scalar is a bare NV with no PV, so every
stringification of it — `print`, interpolation, `"$v"`, a hash key, a log line
— goes through Perl's `%.15g`. A double that needs 16 or 17 significant digits
loses them there, silently.

Measured on a document the real sops wrote, carrying
`ENC[...,type:float]` with the plaintext `0.30000000000000004`, re-measured
today against sops 3.13.3 in both formats:

    sops -d --extract '["ratio"]'   ->  0.30000000000000004
    File::SOPS->extract(...)        ->  0.3

Nothing fails. The document is correct, the ciphertext's plaintext *is* the
canonical decimal, the MAC agrees, `decrypt_file` writes all 17 digits since
ADR 0006. Only this one return value is wrong, and only when the caller turns
it into text.

The loss is specific to values that went through the cipher. An **unencrypted**
YAML float keeps the parser's PV — measured, `YAML::XS` retains the source text
— so `ratio_unencrypted` stringifies with all 17 digits while its encrypted
neighbour stringifies as `0.3`. Two leaves of the same document, two answers.

k61's plan set out three options and the maintainer chose the third:

  (a) keep returning the NV and document `sprintf('%.17g')` in the POD;
  (b) return the canonical decimal as a string, as `sops -d --extract` prints;
  (c) a dualvar: numerically the NV, as a string the canonical decimal.

## Decision

**`extract` wraps a scalar float leaf in a `Scalar::Util::dualvar`** whose
numeric half is the value itself and whose string half is
`File::SOPS::Encrypted->value_to_bytes($value)` — the canonical decimal, which
is also the plaintext on the wire and the bytes the MAC covers.

The text comes from `value_to_bytes` and from nowhere else. A second rendering
of a float, however obviously correct, is the defect class this distribution
keeps re-learning: two conversions that agree today and are consistently wrong
together tomorrow.

`File::SOPS::Encrypted->canonical_float_dualvar` is that one wrapping;
`extract` calls it and decides *where* it applies.

### Where it deliberately does not apply

- **Only the leaf `extract` itself returns.** A branch — `extract(path =>
  '["database"]')` — comes back as the plain structure it always was.
- **`decrypt` and `decrypt_file` are untouched.** They return trees that go
  back into emitters.

Both restrictions are the same measurement. A dualvar inside a tree changes
what this distribution writes:

| leaf | as a bare NV | as a dualvar |
|---|---|---|
| JSON, `0.30000000000000004` | `0.30000000000000004` | `"0.30000000000000004"` |
| YAML, `1e300` | `1e+300` | 301 positional digits |

`Cpanel::JSON::XS` quotes any scalar carrying a PV, and
`File::SOPS::Format::JSON::_float_roundtrips` cannot catch it: it reparses the
quoted string, `value_to_bytes` re-derives that same text from it, and the two
compare equal. Measured end to end, a dualvar in an unencrypted JSON slot
produced `"ratio_unencrypted": "0.30000000000000004"` and `sops -d` read it
back at exit 0 **as a string** — the file is fine, the value has changed type.
So the dualvar is a value to read, and it stops at the boundary where a caller
reads one. Recorded as k78 for the emitter side.

**Amended by k78 / ADR 0011.** The JSON row of that table is no longer
what happens: `_float_roundtrips` now answers *no* when the reparsed leaf is
not a float, and the `Math::BigFloat` carrier writes the canonical decimal as a
**bare number** — measured, byte-identical to the bare-NV document for the
17-digit case, `sops -d` exit 0 with a number read back. The restriction above
still stands, and for the reason the *second* row gives: a dualvar in a tree
still changes what gets written at the magnitudes where `value_to_bytes`'s
positional spelling differs from the emitter's exponent one (`1e300`, `1e20`,
`1e-7`, …, in **both** formats). Those documents are correct — measured, exit 0
and the same double — but they are not the bytes the same value produces
without the dualvar, which is reason enough to keep it out of the trees this
library builds.

- **A non-finite float is returned unchanged.** `NaN`, `+Inf` and `-Inf` are
  `value_to_bytes`'s wire spellings, not a number's decimal; they are already
  `$NO_AGREED_FORM` to the emitters, and `assert_representable` refuses them on
  the encrypt path.

### The spelling is the wire's, which is not always sops's

`value_to_bytes` writes Go's `strconv.FormatFloat(v, 'f', -1, 64)` — shortest
round-tripping digits, **always positional**. `sops -d --extract` prints the
value's YAML/JSON *serialization*, which switches to an exponent at the
magnitudes Go's `%g` does. Measured, same document, sops 3.13.3, **YAML**:

| leaf | on the wire (and from us) | `sops -d --extract` prints |
|---|---|---|
| `0.30000000000000004` | `0.30000000000000004` | `0.30000000000000004` |
| `1.5` | `1.5` | `1.5` |
| `1e20` | `100000000000000000000` | `1e+20` |
| `1e-7` | `0.0000001` | `1e-07` |

The same double either way, and no digits are lost in either spelling. We take
the wire's: it is the text the document actually contains, the text the digest
covers, and it is already computed. Matching sops's printed spelling instead
would mean writing a second float formatter — Go's `%g` rules, reimplemented
next to the `%f` rules we already have — for a cosmetic difference at two ends
of the range. Recorded as k79 in case the maintainer wants the printed
form after all.

**Amended by k79, which closed on this measurement rather than on a
change.** The table above is a YAML measurement and the two ends it names are
examples, not the boundaries. Re-measured against sops 3.13.3 across the whole
double range, one document per row, both formats:

| format | sops prints an exponent when | first magnitude that diverges |
|---|---|---|
| yaml | decimal exponent ≥ 6 or < −4 | `1000000` → `1e+06`, `1e-5` → `1e-05` |
| json | decimal exponent ≥ 21 or < −6 | `1e21` → `1e+21`, `1e-7` → `1e-7` |

Three things follow, and the POD says all three now. The **divergence is
format-dependent**: from a JSON document `1e20` prints as
`100000000000000000000` — the same text this library returns — and the two
agree up to 1e21. The **YAML boundary is far lower than `1e20`**: a plain
`1000000.0` already diverges, which is a much more ordinary value than the one
this ADR chose to illustrate with. And the exponent's own spelling differs
between the formats (`1e-05` in YAML, `1e-7` in JSON), so "Go's `%g`" is two
rules, not one, and matching sops would need both.

What did not change is the property this decision rests on: measured from
`5e-324` through `DBL_MAX`, in both formats and in both slot kinds, **every
spelling either side prints parses back to the identical double** and no digits
are lost anywhere. The cost of the positional form is length — `DBL_MAX` is 309
digits and `5e-324` is `0.` followed by 323 zeros and a `5` — and a `-0.0`
prints as `-0` on both sides.

## Consequences

### What changes for existing callers

`extract` on a float leaf returns a value that is numerically identical and
textually different:

| | before | after |
|---|---|---|
| `$v == 0.1 + 0.2` | true | true |
| `$v + 0` | `0.30000000000000004` | `0.30000000000000004` |
| `"$v"` | `0.3` | `0.30000000000000004` |
| `printf '%s'` | `0.3` | `0.30000000000000004` |
| `printf '%.2f'` | `0.30` | `0.30` |
| `sprintf '%d'` | `0` | `0` |
| `$v eq '0.3'` | true | **false** |
| `is_deeply` against `0.1+0.2` | passes | passes |

The breaking row is the last-but-one: a caller comparing the stringification
against a literal, or using it as a hash key, sees the full digits now. That is
the defect being fixed — the old text was a truncation of the value in the
file — but it is a visible change and it is why this ADR exists.

`extract` on a branch, on a string, an int, a bool or a `type:bytes` value is
untouched, as are `decrypt`, `decrypt_file` and everything else.

### Feeding it back in is safe on the encrypted path, and now on the plain one

`detect_type` reads `SVf_NOK` before `POK`, so a dualvar is a `float` and
`value_to_bytes` re-derives the identical canonical decimal from its numeric
half. Measured: `encrypt(data => { ratio => $extracted })` produces the same
plaintext and the same `type:float` label as the bare NV would.

An **unencrypted** slot was the exception recorded above: in JSON the emitter
quoted it, so a caller who put an extracted float into an `_unencrypted` key in
a JSON document got a string there.

**Superseded by ADR 0011 (k78).** That path now writes a number in both
formats, and the `extract` → `encrypt` round trip a caller most obviously
writes produces a correct document rather than a retyped or refused one. What
survives of this paragraph is the spelling caveat in the amendment above, and
it is the POD that says so.

### Perl magic in a public return value

The cost the plan named, and it is real: nothing about the returned scalar
tells the caller it is a dualvar, and `Scalar::Util::isdual` is the only way to
ask. It was accepted because `extract` returns to *Perl code*, which mostly
wants to compute, while `sops`'s own `--extract` prints to a terminal and can
therefore afford to return text. The dualvar is the only shape that serves both
callers.

## Rejected alternatives

**(a) Keep the NV, document `sprintf('%.17g')`.** Honest and leaves the trap
standing: the default action — printing the value — stays wrong, and the
recipe is not even right, because `%.17g` pads rather than shortens
(measured: `0.1` becomes `0.10000000000000001`, where the wire and sops both
say `0.1`). The caller would have to reimplement `_float_bytes` to get the
text the file contains.

**(b) Return the canonical decimal as a string.** It matches what
`sops --extract` prints and it breaks arithmetic-shaped callers in a way that
is invisible until it matters: `$v` is still numeric in Perl, but a plain
string is a `str` to `detect_type`, so a caller who extracts a float and writes
it back encrypts `type:str`. (`value_to_bytes`'s own return happens to carry
`NOK` today, so it would *not* behave like a plain string — that is an accident
of how `_float_bytes` finds the shortest form, measured and recorded as karr
k80, not a property to build on.) Turning a number into a string on the way out of a
codec is the mirror of the defect ADR 0002 removed on the way in.

**(d) Put the dualvar in `_deserialize_value`, so `decrypt` returns them too.**
The tempting one, because it would also have covered k73 in a single
place. It does neither: a dualvar built on the pre-ADR-0009 NV inherits that
NV's `IOK` and stays an `int` to `detect_type`, and a dualvar in the decrypt
tree reaches both emitters with the measured results in the table above.
