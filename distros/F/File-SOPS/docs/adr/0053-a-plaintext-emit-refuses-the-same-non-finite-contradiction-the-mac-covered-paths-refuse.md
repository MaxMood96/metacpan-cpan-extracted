# ADR 0053 — A plaintext emit refuses the same non-finite contradiction the MAC-covered paths refuse

- Status: accepted
- Date: 2026-08-22
- Resolves k140
- Depends on ADR 0031 (which chose the gate for a non-finite float carrying
  the right token PV) and ADR 0037 (which narrowed the bare-NV repair to a
  leaf with NO public PV, the row the ticket explicitly carved out)
- Uses the discriminator of ADR 0038 — *does sops read back what sops wrote?*
- **Moves no bytes for a valid leaf.** What changes is which documents are
  written at all: a contradicting dualvar that used to reach the file as a
  string now croaks before the file is touched

## Context

A non-finite float Perl carries as a `Scalar::Util::dualvar` has two halves.
The numeric half is what `value_to_bytes` derives the digest from, and the
public string half is what the emitters write. When the two disagree, the
document and the digest state different things, and `sops -d` refuses the
file at exit 51.

The MAC-covered paths caught every one of these already:

- `_compute_mac` calls `assert_representable` per leaf with `encrypted => 1`
  (or `=> 0` for an unencrypted slot); the predicate gates on
  `!_carries_go_non_finite_token` and refuses a contradiction with the
  k59 message, naming the form (`+Inf` / `-Inf` / `NaN`) and pointing
  at type:str.
- `_canonical_floats`'s `mac_covered` croak refuses the JSON case where the
  handler has no spelling for a non-finite value at all, even when the leaf
  carries one of the twelve go-yaml tokens.

The plaintext emit path was the asymmetric third. `decrypt_file`, `edit`,
`_serialize_plaintext` and a direct `emit()` call on a tree the caller built
all go through `_canonical_floats` without `reject_scalar` (no MAC to check
against) and without the metadata `sops:` key (so `_document_carries_mac`
returns false). For a non-finite leaf with a public PV, the walk's existing
predicate returned `$node` as-is when `_carries_go_non_finite_token` was
false:

```perl
return $node unless _carries_go_non_finite_token($node, $text);
```

The emitter then wrote the string half verbatim — `banana`, `Inf`, `.INf`,
`.infinity` — and a later parse retyped the leaf to `str`. A caller who
decrypted a SOPS document into a tree, edited the surrounding keys, and
re-encrypted got every non-finite float it had touched silently retyped,
without a word, with the file still byte-clean against its own MAC only
because no foreign reader ever saw it again. That is the failure mode karr
k140 names.

## The measurement

sops 3.13.3 at `/tmp/sops`, `Crypt::Age` on this machine. One age keypair
generated for the run.

### The bug, reproduced before anything was changed

| tree under `v` | perl `Format::YAML->emit` wrote | what `sops -d` made of it |
|---|---|---|
| `dualvar(+Inf, 'banana')` | `v: banana` | string `"banana"` |
| `dualvar(+Inf, '.INf')` | `v: .INf` | string `".INf"` |
| `dualvar(+Inf, '.infinity')` | `v: .infinity` | string `".infinity"` |
| `dualvar(+Inf, 'Inf')` | `v: Inf` | string `"Inf"` |
| `dualvar(+Inf, '-.inf')` | `v: -.inf` | string `"-.inf"` |
| `dualvar(-Inf, '.inf')` | `v: .inf` | string `".inf"` |
| `dualvar(NaN, '.inf')` | `v: .inf` | string `".inf"` |

Same shape in JSON — Cpanel quotes the public PV when it differs from
`%.15g` of the number, so `dualvar(+Inf, 'banana')` reaches the file as
`{"v":"banana"}` — and the result is identical on the next parse: a
string. ADR 0038's discriminator again: what one writer put on disk, the
other would read as something else.

### What still has to work after the fix

The whole reason ADR 0037 narrowed its repair to the bare-NV row was that
the caller chose the string half deliberately, and overwriting it on the
strength of the number beside it would be the guess ADR 0012 refuses to
make for an integer whose halves disagree. The valid rows must keep
working:

| tree under `v` | perl `Format::YAML->emit` writes | what sops reads it as |
|---|---|---|
| `dualvar(+Inf, '.inf')` | `v: .inf` | `+Inf` (k113 / ADR 0031's row) |
| `dualvar(-Inf, '-.inf')` | `v: -.inf` | `-Inf` |
| `dualvar(NaN, '.nan')` | `v: .nan` | `NaN` |
| bare `+Inf` (no PV) | `v: .inf` | `+Inf` (k134 / ADR 0037's repair) |
| bare `-Inf` (no PV) | `v: -.inf` | `-Inf` |
| bare `NaN` (no PV) | `v: .nan` | `NaN` |

JSON has no spelling at all for a non-finite value in an unencrypted slot
(`sops -d --output-type json` is exit 51 on every one of these), so the
JSON carrier croaks — measured, that is the existing k134 behaviour
and is unchanged by this decision.

## Decision

**The plaintext emit path consults `assert_representable`'s `encrypted => 0`
branch when a non-finite leaf carries a public PV, and croaks with the karr
k59 message the encrypt side already used.**

### 1. One predicate, one place

`assert_representable` already gates on `!_carries_go_non_finite_token` for
both branches (`encrypted => 0` and `=> 1`), with the k59 message that
names the form and points at `type:str`. `_canonical_floats` consults it
under `eval` and prepends `_leaf_location($path)` — the colon-joined key
sequence, `'(document root)'` for the empty path, array indices included.
That is the convention `_compute_mac`'s leaf sweep already uses, with the
same `_reason` strip of the inner `at FILE line N`.

The gate does not drift if the wire format changes: a leaf the encrypt side
refused is refused here, and a leaf the encrypt side accepted is accepted
here, with no per-caller maintenance. `decrypt_file`, `edit`,
`_serialize_plaintext`, and a direct `emit()` on a tree the caller built
all reach the same predicate.

### 2. The gate fires only when the leaf has a public PV

The new consult is `if (_has_public_pv($node))`. Without that filter
`assert_representable` would refuse the bare-NV case ADR 0037 made writable
(k134): the carrier manufactures a `dualvar($double, $token)` for the
leaf in YAML and croaks in JSON, both decisions intact and neither touched
by this ADR.

`_has_public_pv` reads the public `SVf_POK` and not the private one. A
caller who merely printed the value has not promised anything about the
wire, and a guard that read the private flag would refuse a leaf
`assert_representable` would accept.

### 3. The walk's other rows are unchanged

The `mac_covered` croak below the new call still refuses the JSON case
where the handler has no spelling for a non-finite value at all, even when
the leaf carries one of the twelve go-yaml tokens. The new consult runs
*before* it; for a contradiction, the k59 message is the one that
fires, and the JSON case is unreachable for those leaves. For a valid
token PV the new consult passes, and the JSON MAC-covered case croaks with
its existing message as before.

The `assert_representable` body itself is unchanged. The k59 message
text, the form-naming (`+Inf` / `-Inf` / `NaN`), and the `type:str`
suggestion are all untouched.

### 4. `_compute_mac` keeps its own consult with its own `encrypted` value

The encrypt side already calls `assert_representable` per leaf with the
slot-appropriate `encrypted` value (k122 / ADR 0040). The new walk
consult is *redundant* with `_compute_mac` for the MAC-covered paths, and
that is on purpose: the predicate is cheap, and the redundancy is the only
thing that makes the plaintext path symmetric without duplicating the
gate.

## Consequences

- **`decrypt_file`, `edit`, and `_serialize_plaintext` refuse a contradicting
  dualvar they used to write.** Every row above is now an exit-1 with the
  k59 message naming the leaf's path; no file is left behind; no
  reparse will read the leaf as a different type.
- **A leaf the encrypt side refuses is now refused on the plaintext side
  too.** `decrypt_file -> encrypt_file` no longer changes the type of a
  contradicting dualvar silently, because the second step croaks before
  reading it back.
- **`t/52`'s section 4 is inverted** — by one line of expectation, not by
  one line of assertion: the row the previous ADR carved out as "the
  plaintext path preserves the caller's text" is now the row this ADR
  refuses. The subtest was renamed and re-populated; section 5 ("the
  encrypt path answers exactly as it did") is the unchanged pin.
- **No test broke.** `t/46`, `t/52`, `t/54` and the new `t/68` all pass
  against the tree after this change, with the interop sections executed
  against the binary rather than skipped.
- **A file the reference implementation reads is still readable.** `decrypt`
  and `extract` do not go through this walk; they go through `_decrypt_tree`,
  which asks the encryption rules (ADR 0049) and produces the value the
  rule names. The `decrypt` `File::SOPS->decrypt` API is unchanged.

## Limits

- **No parse and no decryption produces a contradicting dualvar.** The
  reachable set is callers who construct one by hand — k140's
  "reachable only by a caller who constructs such a dualvar by hand".
  Reachable, but a deliberate act, which is why this is medium and not
  high.
- **The croak fires with the k59 message and not a path-prefixed
  message from `assert_representable` itself.** The walk prepends the path,
  matching the convention `_compute_mac` already uses; the inner message
  text is unchanged, because the inner code does not know about paths and
  would either get a new argument or stay path-agnostic. The path arrives
  at the front of the message exactly the way every other leaf-shaped
  refusal in this layer arrives.
- **JSON's bare-NV refusal is unchanged.** `_non_finite_token_leaf` still
  croaks with the k134 message for a bare `+Inf` in JSON — the
  carrier cannot reproduce the token, and the rest of the walk is
  unreachable. The new consult does not see a bare NV (`_has_public_pv`
  returns false), so the two refusals remain distinct.

## Rejected alternatives

**Document the bug rather than refuse it.** The plaintext emit silently
  rettypes the leaf on a later parse, which is exactly the failure mode
  every other refusal in this layer exists to prevent. A POD note would
  describe a bug as expected behaviour, and the only mitigation — the
  caller rewriting the tree before re-encrypting — is the same one
  `assert_representable` already enforces for the encrypt side. Refusing
  is symmetric, costs nothing a valid caller notices, and uses the
  message text the encrypt side already had.

**Repair the leaf by dropping the string half.** The carrier already does
  this for a bare NV (k134), where there is no half to drop. A leaf
  the caller chose to give a public PV is a deliberate act; overwriting
  it on the strength of the number beside it is the guess ADR 0012
  refuses to make for an integer whose halves disagree, and ADR 0031 made
  the same call for a non-finite float. The two refusals are the same
  refusal; this ADR extends it to a third caller.

**Move the k59 message into the walk and call the consult from the
  caller.** The predicate is already in `assert_representable`, and the
  message is already there. Moving it out would put the gate in two
  places — the message in the walk, the predicate in the predicate — and
  the next wire-format change would drift them apart, which is the
  signature defect the k113 / 0031 line of work set out to prevent.

**Tighten the gate to refuse the k113 / ADR 0031 row too.** A leaf
  carrying `dualvar(+Inf, '.inf')` is a valid row today: the carrier is
  asked for `.inf`, the answer is `dualvar($double, '.inf')`, the gate
  passes, the emitter writes `.inf`, and `sops -d` reads it as `+Inf`.
  Refusing it would refuse to *write* a document this module *reads*
  correctly, which is the same defect k122 / ADR 0040 closed for
  the encrypted slot.

## Notes

Measured against sops 3.13.3 (`/tmp/sops`) with `Crypt::Age` on this
machine, on 2026-08-22: the seven contradicting rows through perl's
`Format::YAML->emit` and `Format::JSON->emit`; the six valid rows
(`.inf`, `.Inf`, `.INF`, `+.inf`, `-.inf`, `.nan`) on each format; the
three bare NVs (`+Inf`, `-Inf`, `NaN`) on each format; and the seven
contradicting rows through `sops -d` on the YAML perl wrote and on the
JSON perl wrote. All fixtures are invented values; the age keypair was
generated for the run.

`t/68-non-finite-dualvar-emit.t` is the new pin: every refusing row is
the k59 message, every refusing row in JSON is the same, the key
path is in the message for top-level, nested, array-element, and
deeply-nested leaves, and the regression rows (bare NV, valid token PV,
finite float) are kept in the same file. The interop sections of
`t/04-interop.t`, `t/52-non-finite-float-survives-the-encrypted-round-trip.t`,
`t/54-an-encrypted-non-finite-float-is-written.t`, and
`t/67-a-display-form-sops-wrote-is-refused-in-both-stores.t` are executed
against the binary rather than skipped; all pass against the tree after
this change.