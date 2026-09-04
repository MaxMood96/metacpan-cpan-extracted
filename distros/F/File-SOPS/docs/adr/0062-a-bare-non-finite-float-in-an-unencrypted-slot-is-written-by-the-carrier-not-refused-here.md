# ADR 0062 — A bare non-finite float in an unencrypted slot is written by the carrier, not refused here

- Status: accepted
- Date: 2026-08-23
- Resolves k141
- Lane: wire
- Depends on **ADR 0031** (the non-finite guard, whose `!_carries_go_non_finite_token`
  half is left exactly as it is and whose `!_has_public_pv` half this ADR
  reuses), **ADR 0037** (which taught `_non_finite_token_leaf` to ask the
  format handler's carrier for the token, and is the reason the refusal at
  this layer is now redundant in YAML and duplicated in JSON), **ADR 0053**
  (which gave the plaintext emit path the same `assert_representable`
  consult this ADR narrows), and **ADR 0002** (the type comes from the SV,
  and `_has_public_pv` is what reads the public half)
- Does **not** touch `Encrypted::encrypt_value`. An encrypted slot is
  reached by `encrypt_value`, not by `assert_representable` on the read or
  write path, and k122 / ADR 0040 is still the decision that owns
  that slot. The narrowing is `assert_representable`'s `encrypted => 0`
  branch only.
- **Moves no wire bytes for any leaf that already passed.** What changes
  is which leaves pass. A bare NV in an unencrypted YAML slot, which
  `k59 / ADR 0031` refused at exit 1, reaches the file as `.inf`
  / `-.inf` / `.nan` — the byte `sops -d` itself writes for the same
  document — and `sops -d` reads it back at exit 0 as `+Inf` / `-Inf` /
  `NaN`.

## Context

A non-finite float this library encrypts has two paths to the wire:

- an **encrypted** slot, reached by `Encrypted::encrypt_value` (k122
  / ADR 0040 narrows that path to "carries one of go-yaml's twelve tokens
  as its public PV" in YAML and refuses it in JSON)
- an **unencrypted** slot, reached by `_compute_mac` on the encrypt path
  and by `_canonical_floats` on the plaintext emit path (k140 /
  ADR 0053), both of which call `assert_representable` with `encrypted
  => 0`

`assert_representable`'s `encrypted => 0` branch was, until this change:

```perl
croak "value is a non-finite float ($form) and no SOPS document can "
    . "carry it: ..."
    if !$args{encrypted} && defined $form
    && !_carries_go_non_finite_token($value, $form);
```

— a guard with two conjuncts (a non-finite float AND not carrying one of
go-yaml's twelve tokens) and **no third**, refusing every non-finite
float that does not already carry its token PV. ADR 0031 carved out the
"carries a token PV" half; what it left in place was the refusal of every
remaining non-finite leaf at this layer, which is the bare NV.

The bare NV's path to the wire is now different in the two formats, and
that difference is what the ticket names.

### The premise the original guard was written under, and where it stopped holding

The k59 / ADR 0031 guard refused every bare NV because `value_to_bytes`
writes `+Inf` / `-Inf` / `NaN` — Go's `strconv.FormatFloat` text, the
text the digest covers — while the YAML emitter writes a bare `Inf` /
`-Inf` / `NaN` (which go-yaml reads as a string) and the JSON emitter
writes `null`. The premise was that no document could carry a bare NV,
so the only safe answer was to refuse.

ADR 0037 changed both halves. `_canonical_floats` stopped short-
circuiting a bare NV: the leaf now reaches `_non_finite_token_leaf`,
which hands it to the format handler's carrier and verifies the answer.
The YAML carrier answers `dualvar($double, '.inf')`, which the YAML
emitter writes as `.inf` — the exact text go-yaml resolves back to
`+Inf`, byte-identical to what `sops -d` itself writes. The JSON
carrier croaks, with a different message (the existing k134
`_non_finite_token_leaf` croak). The two formats now have different
answers, and the answers live in the carriers.

Re-measured here against sops 3.13.3 at `/tmp/sops`, with
`assert_representable`'s non-finite gate bypassed in a scratch copy of
`lib/`, **unencrypted** slot, one document per row:

| input | YAML | JSON |
|---|---|---|
| bare `9**9**9` | **WRITTEN** as `.inf`, `sops -d` exit 0 | **CROAK** (the JSON carrier) |
| bare `-9**9**9` | **WRITTEN** as `-.inf`, `sops -d` exit 0 | **CROAK** |
| bare `NaN` | **WRITTEN** as `.nan`, `sops -d` exit 0 | **CROAK** |

So the refusal in `assert_representable` for a leaf with **no** public
PV is now:

- **redundant in YAML**: the leaf is written, by the carrier, with the
  right token, and `sops -d` reads it back as the same float;
- **duplicated in JSON**: the same call still refuses, and the JSON
  carrier would also have refused — the croak would just be a different
  message, and the key path the carrier's croak names is the one the
  caller actually needs.

What stays refused at this layer is the leaf with a public PV whose
text is **not** one of go-yaml's twelve non-finite tokens. That refusal
is still load-bearing: `dualvar(+Inf, 'banana')`, `dualvar(+Inf, '.INf')`
and `dualvar(+Inf, '-.inf')` are still `sops -d` exit 51 in YAML if they
reach the file, and the only place they can be refused before the byte
is written is here. Measured, the same twelve rows ADR 0031 pinned as
its "must-not-move" corpus refuse at this layer, with the gate that
ADR 0031 wrote, unchanged.

## Decision

**The `encrypted => 0` branch of `assert_representable` adds the public
PV conjunct that ADR 0031 already used in the `encrypted => 1` branch:
the refusal fires only when the leaf publishes a public string half,
and a bare NV is no longer refused here.** One line, in
`lib/File/SOPS/Encrypted.pm`:

```perl
croak "value is a non-finite float ($form) that also states a string "
    . "half of its own, and an unencrypted slot can carry only one "
    . "of them: ..."
    if !$args{encrypted} && defined $form && _has_public_pv($value)
    && !_carries_go_non_finite_token($value, $form);
```

The four conjuncts together are now: an unencrypted slot AND a non-
finite float AND a public PV AND not carrying go-yaml's token. Drop
the third and the bare NV is written, by the carrier, in the format
the carrier can carry it; in JSON the carrier croaks, with the existing
message and the key path the carrier's croak already names. Drop the
fourth and ADR 0031's row writes too, which it must.

The `encrypted => 1` branch — the one `Encrypted::encrypt_value`
consults — is unchanged. ADR 0040's narrowing is still the decision
that owns the encrypted slot, and k122 is still open for it.

### Why the same `_has_public_pv` half the encrypted slot already gates on

The `encrypted => 1` branch gained `_has_public_pv` in ADR 0040 for the
same reason the `encrypted => 0` branch gains it now: a leaf without a
public PV has no string half to contradict its number, and a refusal
that ran without the third conjunct would be the wrong refusal — for
the encrypted slot it would refuse a leaf the carrier should write,
and for the unencrypted slot it refuses one the carrier already has
written. Both gates fail closed if `_has_public_pv` is wrong about the
scalar it sees (a `_has_public_pv` that said true for a bare NV would
let the contradicting rows write, and they would fail their own MAC);
`_has_public_pv` reads the public `SVf_POK`, which is set by every
parser and by `Scalar::Util::dualvar`, and is the same gate the karr
k168 / ADR 0056 leaf guard uses.

The gate is the same in both branches on purpose: a refusal that ran
in only one would move the leaf class between them, and a leaf that
reached the wire in one branch would not in the other.

### Why this is a narrowing and not a loosening

The refusal's reach is narrower, not the refusal's verdict for a leaf
that still hits it. Every leaf the previous refusal caught and refused
with the k59 message is still caught and refused with the same
gate, the same gate's logic, and — modulo the message reword — the same
verdict. What is removed is one leaf class (the bare NV in an
unencrypted slot) that the carrier now handles in YAML and the JSON
carrier now croaks for in JSON.

A bare NV in an **encrypted** slot still croaks at `encrypt_value`,
unchanged. A contradicting dualvar (any format, any slot) still croaks
here. A valid dualvar (`dualvar($double, $token)` for any of the
twelve tokens) still passes the gate, in either branch.

## Consequences

### What changes for existing callers

| input | before | after |
|---|---|---|
| `rotate` of a sops-written YAML document whose unencrypted slot holds a bare `+Inf` / `-Inf` / `NaN` | croak, k59 message | **written**, `sops -d` exit 0, wire byte-identical to `sops -d` for the same document |
| `encrypt` / `encrypt_file` of a hand-built tree with `v => 9**9**9` (or any of the three spellings) in an unencrypted YAML slot | croak, k59 message | **written**, the carrier's `dualvar($double, $token)`, `.inf` / `-.inf` / `.nan` on disk |
| `decrypt_file` of a sops-written YAML document whose unencrypted slot holds a bare `+Inf` / `-Inf` / `NaN` | croak | written, `.inf` / `-.inf` / `.nan` — what ADR 0037 already wrote in the encrypted-leaf's reverse case |
| `encrypt` / `encrypt_file` of the same bare NV in an **unencrypted JSON** slot | croak, k59 message | **croak**, the JSON carrier's `_non_finite_token_leaf` message — names the key path; the call never reaches the file |
| `rotate` / `decrypt_file` of a JSON document with a bare NV in an unencrypted slot | croak, k59 message | croak, JSON carrier's message; same `sops -d` exit 4 reference answer |
| `dualvar(+Inf, '.inf')` (or any of the twelve tokens) in either format, either slot | YAML written, JSON croak (ADR 0031) | **unchanged** |
| `dualvar(+Inf, 'banana')`, `dualvar(+Inf, '.INf')`, `dualvar(+Inf, '-.inf')` in either format, either slot | croak, k59 message | **unchanged** — still refused, same gate, same twelve-row counter-check |
| a bare NV in an **encrypted** slot, either format | croak, `Encrypted::encrypt_value` (k122 / ADR 0040) | **unchanged** |
| `encrypt` of a finite float (any signed zero, any normal, any subnormal) | written, `type:float`, digest covers the value | **unchanged** |
| `decrypt` / `extract` of any of the above | the float, exactly as ADR 0037 reads it | **unchanged** — the read path is not on this layer |

### Test sections that flip from RED to GREEN

Each of these sections asserted a refusal where the carrier now writes,
or asserted a YAML croak with the k59 message where the carrier
now writes, or split a JSON refusal between k59 and the carrier's
own croak. Each was RED against the unpatched tree and GREEN against
the tree with this change, with the message text updated where the
croak moved from `assert_representable` to the carrier:

| file | section | what it pins |
|---|---|---|
| `t/28-non-finite-float-refusal.t` | section 1 | the **write-side split**: bare NV writes in YAML, croaks with the JSON carrier's message in JSON, contradicting dualvars still refused in both |
| `t/39-yaml-overflow-literal-becomes-a-string.t` | section 11 | a YAML leaf whose overflow resolves to `Inf` is the string sops reads, in both the direct API and the parse-and-write path; the bare-NV narrowing applies to a real `9**9**9` and not to a leaf the parser already typed |
| `t/42-yaml-plain-infinity-is-a-float.t` | section 11 | a plain `.inf` resolves to a `+Inf` carrying `.inf` as its PV; the parse produces the leaf this ADR no longer refuses at write time |
| `t/46-non-finite-token-is-written.t` | sections 4-5 | `assert_representable` answers YES for a bare NV in either slot and NO for a contradicting dualvar; the message names the form (`+Inf` / `-Inf` / `NaN`) and points at the carrier (YAML) or the JSON carrier's refusal |
| `t/52-non-finite-float-survives-the-encrypted-round-trip.t` | section 9 | ADR 0037's twelve-row encrypt-path counter-check: all twelve rows in both formats still refuse or write exactly as before; the bare-NV narrowing does not touch the table |
| `t/54-an-encrypted-non-finite-float-is-written.t` | sections 1, 4, 5 | the encrypt-side `assert_representable` consult now answers YES for a bare NV in all three slots (default, `encrypted => 0`, `encrypted => 1`) and NO for every contradicting dualvar; the unencrypted YAML leaf under the rule walks out as `.inf` / `-.inf` / `.nan` rather than croaking |

### Wire bytes that move

- **Bare NV in an unencrypted YAML slot.** What used to be no bytes
  (the refusal croaked before the file was touched) is now
  `.inf` / `-.inf` / `.nan` — the byte `sops -d` itself writes for
  the same document.
- **Nothing else.** The encrypted slot is unchanged (k122 owns it).
  The contradicting dualvars in either format are unchanged. JSON is
  unchanged: the call still croaks, and the message moves from the
  k59 wording to the JSON carrier's wording, which already names
  the key path. A document that did not carry a bare NV in an
  unencrypted slot is byte-identical — measured before and after
  against the full corpus of every format, every slot, every dualvar
  shape the carrier was never asked about.

### What this leaves broken, and why it is filed rather than fixed

- **`edit` of a JSON document with a bare NV in an unencrypted slot
  still croaks**, with the JSON carrier's message. The carrier cannot
  reproduce the token, JSON cannot spell a non-finite float at all
  (measured, `sops -d --output-type json` is exit 51 on every spelling
  sops writes), and the croak is the same answer the reference
  implementation gives. Not a defect; the same trade ADR 0037 made for
  the encrypted slot, with the same ticket named as the thing that
  could change it (none filed: the carrier does not exist for JSON).
- **A bare NV in an encrypted slot still croaks** at
  `Encrypted::encrypt_value`, unchanged. k122.

## Rejected alternatives

**Remove the `encrypted => 0` branch entirely and let the carrier (in
YAML) or the JSON carrier's croak (in JSON) be the only refusal.**
Tighter. Rejected because it would refuse the contradicting dualvars
in YAML by croaking in the carrier for a leaf the carrier can carry,
and would lose the message that names the form and points at `type:str`
— the only message a caller with `dualvar(+Inf, 'banana')` by hand has
to act on. The two refusals are different refusals: the carrier refuses
"no token a YAML emitter can write", the gate refuses "your token says
something your number does not". The k59 message names the second
verdict; the carrier's message names the first.

**Move the gate to `_canonical_floats`'s `mac_covered` croak instead.**
The walk already knows the format and the key path. Rejected because
`_compute_mac` calls `assert_representable` first and would still croak
for every bare NV — the gate would have to live in two places, with the
key path concatenation duplicated, and a future change to the gate would
drift in the way the k113 / 0031 line of work set out to prevent.
The narrowing is one conjunct in the predicate both call.

**Add the public PV conjunct in `_compute_mac` and leave
`assert_representable` alone.** The plaintext emit path (ADR 0053) does
not call `_compute_mac`; it calls `assert_representable` directly. The
narrowing has to be in `assert_representable` or it cannot reach the
plaintext path.

**Run the JSON carrier from `assert_representable` for the
`encrypted => 0` branch.** Format-blind for a format-bound question.
The JSON carrier is format-specific on purpose: it is the place JSON
says "no" and is the place the carrier's message lives. Pulling it up
into the format-blind layer would put the format signal in the layer
the format signal is supposed to leave alone (ADR 0037's argument for
the carrier as the only signal available).

**Keep the gate as-is and document the divergence with `sops -d`.**
Makes permanent a leaf class `sops -d` writes at exit 0 (a bare `.inf`
in an unencrypted YAML slot) and this library refused at exit 1. The
whole claim of this distribution is byte compatibility, and the
document in question is one `sops -e` writes from a plaintext
`.inf` by default.

## Notes

Measured against sops 3.13.3 (`/tmp/sops`) on 2026-08-23: the three
bare NVs through `assert_representable` directly (default slot,
`encrypted => 0`, `encrypted => 1`), the twelve-row ADR 0037
counter-check corpus through the same predicate, and the three bare
NVs through `File::SOPS->encrypt` and `File::SOPS->rotate` in both
formats. The six test sections flipped from RED to GREEN above pass
against the tree after the change; the full suite is **1364/1364
across 74 files**, with `t/04-interop.t` and the other interop
sections executed rather than skipped (sops 3.13.3, `/tmp/sops`).
`prove -lr t/` runs at 74 files, 1364 tests, all PASS.

The narrowing is one conjunct in one predicate and a message reword
that names the carrier as the place the format signal lives. One
behaviour change in `lib/File/SOPS/Encrypted.pm`. Six test sections
updated (the table above). No other file changed. The encrypted slot's
`Encrypted::encrypt_value`, the `Encrypted::canonical_float_tree`
walks, the JSON carrier's `_non_finite_token_leaf` croak, and the
plaintext emit's ADR 0053 consult are all untouched.

Lane: wire. The decision moves the value→bytes conversion's first line
of defence; both branches of the predicate that ADR 0031 / ADR 0040
narrowed share the same gate, and keeping them in step is the property
this ADR inherits from the k113 / 0031 line of work.