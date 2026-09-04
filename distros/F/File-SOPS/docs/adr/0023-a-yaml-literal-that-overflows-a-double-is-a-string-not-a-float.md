# ADR 0023 — A YAML literal that overflows a double is a string, not a float

- Status: **accepted** — decided and implemented together, in this commit. The
  measuring pass (`file-sops-format`, 2026-08-21) deliberately wrote no ADR for
  a change nobody had taken, and left the decision to the lane that moves the
  digest. Every table below was re-measured here against sops 3.13.3 at
  `/tmp/sops` rather than inherited; where a number differs from the handover's
  it is because this pass swept a wider corpus, and that is marked where it
  sits.
- Date: 2026-08-21
- Tags: float, str, yaml, wire-format, interop, parser, mac
- Resolves k102
- Depends on ADR 0002 (the type comes from the SV's public flags — which is why
  the answer has to be a different SV and not a different label, and why the
  predicate reads flags rather than text), ADR 0006 (`FormatFloat(v,'f',-1,64)`
  as a float's digest, which is what produced the `+Inf` this replaces),
  ADR 0013 and ADR 0017 (the Go resolution model in `Format::YAML`, which
  already answers correctly for every spelling below and needs no change) and
  ADR 0020, which named this ticket as the lever and expected it to answer for
  **both** parsers at once — measured here, it must not
- Neighbours, deliberately **not** resolved here: k105 (a bare `.inf`
  written by sops fails our MAC — the same magnitude, the opposite direction,
  and its repair would collide with the guard this one leaves alone) and
  k106 (a literal that *underflows* to zero, where no non-finite NV ever
  appears and this predicate cannot fire)

## Context

`File::SOPS` could neither read nor write a YAML document containing a numeric
literal too large for a double. Both halves reproduced at c8eee80, sops 3.13.3:

    plaintext   keep: x
                v_unencrypted: 1e400

    sops -e     exit 0, the literal reaches the file verbatim, type:str
    sops -d     exit 0

    File::SOPS->decrypt of that same file
      -> MAC verification failed
    File::SOPS->encrypt of the same tree
      -> croak, "value is a non-finite float (+Inf)"

The **read** half is the one k102 was filed without. A file sops writes and
sops verifies is unreadable here, and for a distribution whose entire claim is
byte compatibility that is the centre of the ticket rather than its edge.

### Where the behaviour actually flips

Not at a digit count, and not at `uint64` — at `strconv.ParseFloat`'s
`ErrRange`. Measured, one `sops -e` per row, encrypted and unencrypted slot:

| literal | `sops -e` | encrypted slot | unencrypted slot |
|---|---|---|---|
| `1` + 18 zeros | exit 0 | `type:int` | verbatim |
| `1` + 19 zeros | **exit 23** | — | `Cannot walk value, unknown type: uint64` |
| `1e20` … `1e308` | exit 0 | `type:float` | rewritten `1e+20` … `1e+308` |
| `1e309`, `1e400` | exit 0 | **`type:str`** | verbatim |

On the bit, at the rounding threshold, both literals 309 digits long:

| literal | sops |
|---|---|
| `2**1024 - 2**970 - 1` | `type:float`, wire `1.7976931348623157e+308` |
| `2**1024 - 2**970` | **`type:str`**, wire verbatim |

**Perl flips at the same token.** `YAML::XS` returns the first as a finite NV of
`1.7976931348623157e308` and the second as `+Inf`. Go's `ErrRange` and Perl's NV
going non-finite are one IEEE-754 condition, so the model this decision needs
does not have to be invented — it is already in the SV.

### The same mechanism, a second class of spellings

`Inf inf INF Infinity infinity NaN nan NAN -Inf +Inf -inf +inf -nan` come back
from `YAML::XS` the same way: `SVf_NOK` set, `SVf_POK` set, NV non-finite. sops
leaves every one of them a `type:str` and writes it verbatim, exit 0. They are
not a separate ticket; they are the same defect reached by a different spelling,
and the same repair covers them.

### What was broken, counted

20 documents, each `keep: x` plus one of the 10 overflow literals or 10
spellings in an unencrypted slot, written by `sops -e` and read back by
`sops -d` (exit 0 for all 20). At c8eee80:

| direction | before | after |
|---|---|---|
| `sops -e` → `File::SOPS->decrypt` | **3 of 20 read** | 20 of 20 |
| `File::SOPS->encrypt` → `sops -d` | **0 of 20 written** (20 croaks) | 20 of 20, `type:str` as sops writes |

The three that read are `NaN`, `-Inf` and `+Inf`, and they read by coincidence:
`FormatFloat` happens to render those three doubles as the very text the source
token used. Every other spelling digested `+Inf` where Go digested the token.

### Why the predicate cannot retype a leaf Go reads as a float

This is the claim the whole change rests on, and it was verified against the
binary rather than argued.

The only tokens go-yaml resolves to a real non-finite float are the twelve in
`Format::YAML`'s `%GO_CONSTANT`: `.inf .Inf .INF +.inf +.Inf +.INF -.inf -.Inf
-.INF .nan .NaN .NAN`. **`YAML::XS` hands back every one of them `SVf_POK`
only** — a plain string, no NV — so none of them can fire a predicate that
requires `SVf_NOK`. Measured both ways:

| set | size | `sops -e` says | fires the predicate |
|---|---|---|---|
| `%GO_CONSTANT`'s inf/nan tokens | 12 | `type:float` | **0 of 12** |
| tokens the predicate fires on | 29 | `type:str`, all 29 | 29 of 29 |

The 29 are the whole firing set of an 80-token sweep of every shape libyaml
resolves numerically at overflow magnitude — decimal integers, exponent floats,
decimal-point forms, both rounding neighbours, and the spelling class above.
Nine further inf/nan spellings that are *not* in `%GO_CONSTANT` (`.INf`, `.iNF`,
`.Nan`, `.NAn`, `+.nan`, `-.nan`, `-.NAN`, `.infinity`, `.Infinity`) were put
through the binary as well: all nine are `type:str` to sops, confirming the
table is complete and not merely plausible.

**The two sets are disjoint, with the binary as the witness.**

## Decision

**`File::SOPS::Format::YAML::parse` replaces a leaf whose NV is non-finite with
its own string half, so that the rest of the distribution is handed the leaf
go-yaml sees.**

The walk runs after the `sops` section is split off and before `parse` returns.
Its predicate is the SV and never the text (ADR 0002): a defined, unreferenced
scalar with **public** `SVf_NOK` and **public** `SVf_POK` set, whose NV is `NaN`
or `±Inf`. The replacement is a plain copy of the scalar's PV. Nothing numifies
anything — `B` reads the NV and the PV out of the SV's own slots — so the walk
cannot retype a caller's scalar the way a numeric comparison on it would
(k32).

Three things this deliberately is not:

- **It is not a loosened guard.** The non-finite refusal from k59 is
  untouched, and a caller who hands `encrypt` a real `9**9**9` still gets it
  (measured, 6 of 6 croaks before and after, encrypted and unencrypted slot
  alike). What is removed is an artefact of *our parser*, not a rule about
  values.
- **It is not the Go model.** `_go_scalar_bytes` already answers correctly for
  all 29 spellings — `_go_float` returns undef on `ErrRange` and the token falls
  through as a string. Nothing in the emitter, the guard or the digest changes.
  The only thing that was wrong was our own parse result.
- **It is not applied to JSON.** ADR 0020 predicted this lever would answer for
  both parsers at once. Measured, it must not: `sops -e` refuses an overflowing
  JSON number at unmarshal time (`strconv.ParseFloat: value out of range`,
  exit 2), so the croak `Format::JSON`'s leaf earns there **is** the reference
  behaviour, and quieting it would make us accept a document sops rejects.

### Why parse, and not anywhere else

`parse` is where the read path and the write path cross: `decrypt` parses the
encrypted document and takes its unencrypted slots from that tree, and
`encrypt_file` parses the plaintext. One walk covers both. Putting it in
`detect_type` would be a second type ladder; putting it in the emitter would
mean deciding a string's type from its text, which is what ADR 0002 removed.

The order-preserving reparse (ADR 0001) is unaffected, and that was checked
rather than assumed. `_document_leaves` takes **order** from the YAML::PP tree
and every **value** from the parsed tree, so a retyped leaf reaches the digest
through the side the walk has already corrected. YAML::PP loads all 29 firing
tokens plus the twelve constants and yields a scalar wherever YAML::XS yields
one: 0 structural mismatches in 32, so the parallel walk still pairs up.

## Consequences

### Wire bytes that move

A YAML leaf whose literal libyaml resolved to a non-finite double. Its digest
input changes from `+Inf` / `-Inf` / `NaN` to the literal's own text, and its
`type:` from `float` to `str` — which is what sops writes for the same document.
27 of 105 corpus rows move, and **every one of them is a row whose
`value_to_bytes` was `+Inf`, `-Inf` or `NaN`**. Nothing that worked moves: the
twelve `%GO_CONSTANT` spellings, a quoted `"1e400"`, `1e-400`, `-0`, `5e-324`,
`1.7976931348623157e308` and the rounding neighbour one bit below the threshold
are all byte-identical before and after.

### The unencrypted slot comes out quoted where sops writes it bare

`YAML::XS` quotes a string its own resolver would read as a number, so
`v_unencrypted: 1e400` is written `v_unencrypted: '1e400'` where sops writes it
bare. Both spellings are a **string** to both parsers, so the digest is the same
text either way and `sops -d` exits 0 on both (measured, 20 of 20).

This is **not** the "quote the leaf on the way out" that ADR 0013 rejected. That
proposal retyped a leaf — writing `mode: "0755"` where the caller's parser and
sops both said integer — to keep our own MAC intact. Here nothing is retyped on
the way out: the leaf is already the string both implementations read, and the
quotes are only how `YAML::XS` spells a string that looks numeric.

### `!!float 1e400` is retyped with the rest

`YAML::XS` strips the tag and hands back the same non-finite NV, so an
explicitly tagged literal takes the same path and becomes a string. sops does
not agree — but it does not accept the input either: `sops -e` on that document
is exit 2, `yaml: cannot decode !!str `1e400` as a !!float`. The divergence is
therefore only in the permissive direction, on a document the reference refuses
outright, and narrowing it would cost a tag-aware parse for no reachable case.

### `x_unencrypted: NaN` and `x_unencrypted: -Inf` return something different

A caller who reads such a document out of `decrypt` or `extract` used to get a
real Perl `NaN` / `-Inf`. They now get the strings `'NaN'` and `'-Inf'`.

**This is the correction, not the breakage.** sops reads a string in that slot,
digests those four characters, and hands its own callers a string; we were the
only one of the two implementations that read a number there. The old value was
also not usable: of the thirteen spellings in that class, ten failed
verification outright, and the three that verified did so only because
`FormatFloat` happened to render their double as the source text. What changes
for a caller is that a slot which mostly could not be read at all now reads, and
reads what the other implementation reads.

### What changes for existing callers

| input | before | after |
|---|---|---|
| YAML, `1e400` / 401 digits / `Inf` / `NaN` in an **unencrypted** slot | MAC verification failed on read; croak on write | reads and writes, `type:str`, as sops does |
| the same in an **encrypted** slot | croak (`assert_representable` runs before encryption) | `type:str`, the literal verbatim — sops's own token |
| `decrypt` / `extract` of such a slot | a real Perl `Inf` / `NaN`, on the three documents that read at all | the literal's text |
| an **encrypted** `type:float` whose plaintext is `+Inf` / `-Inf` / `NaN` | a real Perl non-finite float | **unchanged** — byte-identical doubles, measured `000000000000f07f` / `f0ff` / `f8ff` before and after |
| `encrypt(data => { v => 9**9**9 })` | croak (k59) | **unchanged** — croak |
| a bare `.inf` in an unencrypted slot | MAC verification failed | **unchanged** — k105 |
| `1e-400` | `type:int`, digest `0` | **unchanged** — k106 |
| JSON, any of the above | croak | **unchanged** — croak, which is what sops does |

### Cost

One tree walk per YAML parse, reading two flags per scalar leaf. It carries its
own visited set, because a recursive YAML anchor (`root: &a` / `b: *a`) really
does come back from `YAML::XS` as a cycle; that keeps this walk terminating and
does not pretend to fix the encrypt and decrypt walks, which hang on such a
document today and are filed as k110.

## Rejected alternatives

**Accept the divergence and document it** — k102's own option (ii). It was
written before the read half was measured, and the read half is what removes it
from the table: it would make permanent the statement that valid `sops` output
is unreadable here, for ten documents the reference writes and verifies.

**Loosen the non-finite guard so the write path stops croaking.** It fixes the
half of the ticket that was filed and none of the half that matters, and it is
wrong on its own terms: the guard is right about every value it was written for
(ADR 0013's measurement — the JSON emitter writes `null`, `YAML::XS` writes bare
`Inf`, and what one writes the other cannot read back). The ticket says not to,
and the measurement agrees.

**Fix it in the emitter — write the source text back out.** It would need the
emitter to decide, from a value's text, that this particular float is really a
string. That is the pattern-matching ADR 0002 removed, and it would leave the
read path broken, because on read there is no emitter in the way.

**Fix it in `detect_type` — a rung for a non-finite NV that carries a PV.** One
line, in the single source of truth for the type. It moves the digest correctly
and leaves the *value* wrong everywhere else: `decrypt` would still hand a
caller a `+Inf` for a slot that holds the text `1e400`, and `extract` likewise.
The defect is a parse result, so the parse result is where it is repaired.

**Model go-yaml's resolution for the overflow case explicitly**, next to
`_go_int` and `_go_float`. That model already exists and is already right —
`_go_float` returns undef on `ErrRange` — and it answers a question about
*emitted bytes*, not about what our own parser handed us. Adding a second
copy of the overflow rule for the parse side is exactly the duplication this
distribution names as its signature defect.

**Widen the predicate to any leaf whose Go-resolved type differs from ours.**
That is a general widening with its own corpus and its own failure modes, and it
is what k106 asks as an open question. It would also swallow k105,
whose repair has to go the *other* way — manufacture a real `+Inf` where our
parser has a string — and would then collide with the k59 guard. Those two
are separate tickets because they are separate decisions.

**Ask `YAML::PP` what the leaf is.** Rejected here for the reason ADR 0013 gives:
it is a second parser that agrees with the first, and agreement between our two
parsers is the failure mode this distribution ships against. Measured for this
case anyway — YAML::PP is consulted for order only, and its answer is not read.
