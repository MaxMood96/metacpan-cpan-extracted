# ADR 0037 — A non-finite float is written as a token, or not at all

- Status: **accepted** — decided and implemented together, in this commit. Every
  table below was measured here against sops 3.13.3 at `/tmp/sops`; the
  candidate fix was built in a scratch copy of `lib/` and measured there before
  anything in the repository changed.
- Date: 2026-08-21
- Tags: float, yaml, json, editor, wire-format, interop, mac
- Resolves k134. Files k140 (a contradictory string half in a
  plaintext emit) for what it deliberately leaves alone, and adds a measured
  note to k122, whose stated premise did not survive this measurement.
- Depends on ADR 0026 (which taught the parse to read a plain token back as the
  float go-yaml resolves), ADR 0031 (whose gate, table and verdict this reuses
  unchanged, and whose `return $node` short-circuit this replaces), ADR 0034
  (which made the repair run on every parse, and is what closes the circle),
  ADR 0006 (`+Inf` / `-Inf` / `NaN` as a non-finite float's digest text),
  ADR 0013 and ADR 0017 (the foreign-resolution guard, still the verdict) and
  ADR 0002 (the type comes from the SV; nothing here reads a leaf's text to
  decide what it is)
- Does **not** touch `Encrypted::encrypt_value`'s refusal of a non-finite float
  in an encrypted slot. That is k122, it is what stops this change from
  closing the `edit` round trip, and it is named in "What this leaves broken"
  with the measurement that reopens it

## Context

ADR 0034 closed the **unencrypted** half of the plaintext round trip: a plain
`.inf` in an unencrypted slot now survives `decrypt_file`, `edit` and
`encrypt_file`. The **encrypted** half was filed at the same time, and it is
worse, because it says nothing. Reproduced at 4aa9ace, sops 3.13.3, one
document per row, key `secret` in an encrypted slot:

| step | `.inf` | `-.inf` | `.nan` |
|---|---|---|---|
| `sops -e` | `type:float`, plaintext `+Inf` | `type:float` | `type:float` |
| `sops -d` | `secret: .inf` | `secret: -.inf` | `secret: .nan` |
| `File::SOPS->decrypt_file` | **`secret: Inf`** | **`secret: -Inf`** | **`secret: NaN`** |
| `File::SOPS->edit`, editing an unrelated key | returns 1, wire **`type:str`** | returns 1, **`type:str`** | returns 1, **`type:str`** |
| `sops edit`, same document, same editor | exit 0, wire unchanged, `type:float` | exit 0, `type:float` | exit 0, `type:float` |

No error, no warning, and `sops -d` reads the rewritten file at exit 0 — stating
a string where the document held a number. A user who edits a completely
unrelated key silently loses the type of a leaf they never touched.

### The mechanism, and where the information is destroyed

The encrypted leaf decrypts to a real Perl infinity: a scalar whose only form is
its number. `YAML::XS::Dump` writes such a scalar as a bare `Inf` / `-Inf` /
`NaN` — tokens go-yaml resolves as **strings**, and correctly so, which is why
ADR 0026's repair cannot reach them and must not learn to. So the editor is
shown `Inf`, the string `Inf` comes back, `detect_type` says `str`, and the leaf
is re-encrypted as `type:str`.

The loss happens at the **emit**. By the time the plaintext is reparsed there is
nothing left to recover: `Inf` really is the string `Inf` to every reader,
including sops.

The ticket's claim about where the short-circuit sits was verified first, since
the whole assignment rests on it. `Encrypted::_canonical_floats` reaches

```perl
if ($text =~ $NO_AGREED_FORM) {
    return $node unless _carries_go_non_finite_token($node, $text);
```

for a bare non-finite NV and returns before any handler hook runs. Measured with
a `canonical_float_tree` call whose three callbacks record being called: for
`+Inf`, `-Inf` and `NaN`, **none of `roundtrips`, `carrier` or `reject_scalar`
is invoked**, and the leaf leaves the walk as the bare NV it arrived as. So no
handler can see this leaf, and no fix in `Format::YAML` alone can reach it.

### JSON is not the same defect — it is a worse one

The ticket describes a retyping. Measured, JSON loses the value outright:

| document, `secret` encrypted, JSON wire | before |
|---|---|
| `File::SOPS->decrypt_file` | writes **`"secret": null`** |
| `File::SOPS->edit`, editing an unrelated key | returns 1; the wire loses its `ENC[...]` and holds a bare, **unencrypted `null`** |
| `sops -d --input-type json --output-type json` | **exit 4**, `json: unsupported value: +Inf` |
| `sops edit` on the same document | **exit 4**, `Could not marshal tree` |

So where sops refuses the document outright, this library silently replaced an
encrypted secret with a plaintext `null`. That is the defect class this layer
exists to prevent, and it is not a retyping — the value is gone.

### The target form, measured rather than chosen

`sops -d` on an encrypted `type:float` writes the token, in the one spelling per
value that `sops -e` itself writes. Twelve `sops -e` runs, three plaintexts, both
wire formats:

| plaintext | wire | `sops -d --output-type yaml` | `sops -d --output-type json` |
|---|---|---|---|
| `.inf` | `type:float`, plaintext `+Inf` | **`secret: .inf`**, exit 0 | exit 4 |
| `-.inf` | `type:float`, plaintext `-Inf` | **`secret: -.inf`**, exit 0 | exit 4 |
| `.nan` | `type:float`, plaintext `NaN` | **`secret: .nan`**, exit 0 | exit 4 |

Both rows of the JSON column are the same for a YAML wire document and for a
JSON one — measured, six documents, all six exit 4. **JSON is not a wire format
sops refuses; it is an output format sops cannot produce.** There is therefore
no reference answer to copy for a JSON plaintext, and this ADR has to give one
of its own. It gives sops's: refuse, and say why.

And `.inf` is exactly what ADR 0026's repair reads back as a float — which since
ADR 0034 it does on **every** parse, plaintext included. The circle closes on
bytes that were already there.

## Decision

**A non-finite float leaf with no string half of its own is given the token the
emitter writing this document can carry — and where the emitter has none, the
leaf is refused rather than written.** Two parts, both in
`lib/File/SOPS/Encrypted.pm`:

1. **`_canonical_floats` stops short-circuiting.** A leaf whose canonical text
   matches `$NO_AGREED_FORM` and that publishes no `SVf_POK` goes to
   `_non_finite_token_leaf` before ADR 0031's existing three-line verdict, and
   arrives there in the shape that verdict was written for. Nothing about the
   verdict changes.

2. **`_non_finite_token_leaf` asks the emitter, and verifies the answer.** It
   hands the leaf and the token to the handler's own `carrier` — the hook whose
   documented job is "returns the replacement, and is format-specific" — and
   accepts what comes back only if it is an unreferenced scalar that
   `_carries_go_non_finite_token` accepts for the same bytes and that
   `value_to_bytes` still renders as those bytes. Both halves, checked with
   ADR 0031's own gate. Anything else, a carrier that dies included, is a croak
   naming the key path.

Measured, the two carriers answer this question without being changed:

| handler | `carrier->($inf, '.inf')` | emitted |
|---|---|---|
| `Format::YAML` | `dualvar(+Inf, '.inf')` | `v: .inf` |
| `Format::JSON` | croaks — `Math::BigFloat->new('.inf')` does not reproduce the text | — |

### Why the carrier is the format signal, and the only one available

`canonical_float_tree` is format-blind by construction, and the format is known
in `File::SOPS` and in the handlers, nowhere in between. ADR 0031 needed the same
distinction and read it off `reject_scalar`, which the YAML handler installs and
the JSON handler cannot. That signal is **not available here**: a plaintext
emit installs no `reject_scalar` in either format — deliberately, because a
document with no MAC has no second reader to disagree with — and the plaintext
emit is the entire subject of this decision.

Three other candidates were measured and rejected:

- **`roundtrips`.** Asked honestly — does the emitter's output come back as the
  number the digest covers — it answers **no for YAML**, because it reparses with
  libyaml and libyaml reads `.inf` back as a string. ADR 0013's founding
  observation: a local reparse cannot answer a question about a foreign
  resolver. Asked dishonestly, with the token substituted for the digest text,
  it happens to answer yes for YAML and no for JSON — but only because the JSON
  handler's copy also compares `detect_type` and the YAML handler's does not.
  That is a coupling to a difference between two callbacks that neither was
  written to express, and a perfectly reasonable hardening of the YAML one would
  silently turn every YAML plaintext into a refusal.
- **A new named argument** — `non_finite_token => 1` from `Format::YAML`, or the
  inverse from `Format::JSON`. It is the shape this would take if the handlers
  were in scope. They are another lane's files, and it buys nothing the carrier
  does not already give: the handler would be declaring what its carrier can
  already be asked to do.
- **Modelling the emitters here.** "YAML can, JSON cannot" is four characters
  and a second copy of a fact that belongs to the handler, in a file that has no
  business knowing which formats exist.

Asking the carrier keeps the question where the answer is, adds nothing to any
handler, and — because the answer is verified rather than trusted — **fails
closed in both directions**. A carrier that stops producing the token refuses
the document instead of writing a wrong one; a carrier that produces something
unexpected is refused by the gate that already decides whether such a leaf is
writable at all.

### Why only a leaf with no string half of its own

The replacement fires on `!_has_public_pv($node)` — a scalar whose only form is
its number — and on nothing else. That is exactly the leaf a decrypted
`type:float` produces, and exactly the leaf whose spelling nobody has stated.

A non-finite float that **does** publish a string half has stated one, and it is
left alone whatever it says. That is ADR 0031's trap, checked in both
directions:

| leaf | encrypt path (`File::SOPS->encrypt`) | plaintext emit |
|---|---|---|
| bare `9**9**9` | croak, `assert_representable` — **unchanged** | `.inf` (was `Inf`) |
| `dualvar(+Inf, '.inf')` | YAML written, JSON croak — **unchanged** | `.inf` — **unchanged** |
| `dualvar(+Inf, 'banana')` | croak — **unchanged** | `banana` — **unchanged** |
| `dualvar(+Inf, '.INf')` | croak — **unchanged** | `.INf` — **unchanged** |
| `dualvar(+Inf, '-.inf')`, `dualvar(-Inf, '.inf')` | croak — **unchanged** | their own text — **unchanged** |

The `banana` row is the one ADR 0031 built the gate for, and it is the reason
the replacement is not simply "any non-finite float": widening it would let this
walk overwrite a string half a caller chose, on the strength of the number
beside it, which is the guess ADR 0012 refuses to make for an integer whose
halves disagree. **Nothing a caller can construct becomes writable to a
MAC-covered document that was not writable before** — `assert_representable`
runs first, from `_compute_mac`'s leaf sweep, and its gate is untouched.

A plaintext emit of `dualvar(+Inf, 'banana')` still writes `banana`, which is
its own small defect and predates this change. Filed as k140 rather than
absorbed.

### What was measured

Every row below is a real run against sops 3.13.3, before (repository at
5ed2dc0) and after (the same tree with this change).

- **The ticket's rows, YAML.** `sops -e` → `decrypt_file`, three spellings: the
  leaf line goes from **0 of 3** byte-identical to `sops -d`'s to **3 of 3**.
  `sops -e` → `edit` of an unrelated key: three silent `type:str` rewrites
  become three croaks naming the key path, with the wire left untouched at
  `type:float`.
- **The ticket's rows, JSON.** `decrypt_file` writes `"secret": null` before and
  croaks after; `edit` silently replaces the `ENC[...]` with a bare unencrypted
  `null` before and croaks after. `sops -d --output-type json` and `sops edit`
  are exit 4 on the same three documents, before and after.
- **The circle.** `emit` → `parse` of a bare `+Inf` / `-Inf` / `NaN` in a
  plaintext YAML document: before, the leaf comes back a `str` (and for `+Inf`
  the digest text moves from `+Inf` to `Inf`); after, it comes back a **`float`**
  whose `value_to_bytes` is the text it went in as, for all three, with the
  document's own token as its string half.
- **ADR 0034's 24-row plaintext corpus**, twelve tokens × two slots through
  `encrypt_file` and handed to `sops -d`: 12 written / 12 exit 0 in the
  unencrypted slot and 12 croak in the encrypted one, **identical before and
  after**.
- **ADR 0031's 12-row encrypt-path table** (bare NV, the matching dualvar, the
  three contradictions, the near miss and `banana`, two formats): **identical
  before and after**, message for message.
- **15 must-not-move parse-and-emit rows**: the three tokens quoted, seven near
  misses (`.INf` `.iNF` `+.nan` `.infinity` `Inf` `inf` `NaN`), `config.info`,
  `1e400`, `3.14`, `-0.0` and `007`. **None moves.**
- **`mac_only_encrypted`**, both formats: unchanged, no new warning.
- **Nested leaves**: an infinity inside an array and three levels down a hash
  are written as tokens in YAML and refused in JSON with the path (`list:1`) in
  the message.
- `prove -lr t/` was **1157/1157 at 5ed2dc0** (52 files) and is **1172/1172**
  (53 files) with the new file and the two replaced claims below, no other test
  edited.
  `SOPS_BIN=/tmp/sops prove -l t/04-interop.t` is **32/32, executed rather than
  skipped**, before and after.
- **Counter-check:** `t/52-non-finite-float-survives-the-encrypted-round-trip.t`
  run against the unpatched 5ed2dc0 with `perl -I` and no `use lib` in the file —
  **9 of its 15 subtests and 80 assertions fail**, and every one of the six that
  pass is a must-not-move section: the leaf that already carries a token, the
  stated string half, the encrypt-path table, the encrypted slot's refusal,
  `sops edit`'s own answer, and ADR 0034's unencrypted rows.

### The two claims this replaces

Both pinned the short-circuit rather than the thing they were written to
protect, and both are edited in place rather than deleted:

- **`t/46` section 6**, `canonical_float_tree leaves a plaintext document
  alone`. Its point is that a document with no MAC keeps the leaf it has, and
  that is still true of the leaf it names — the token-carrying one, which is
  what the whole file is about. It also asserted that the carrier was never
  called at all, over a tree that carried a bare `+Inf` beside it, and that half
  is the defect. The subtest now asserts that the **token-carrying** leaf is
  untouched and the carrier is never asked about it, and that the **bare** one is
  the single leaf the carrier is asked to replace.
- **`t/49` section 8**, `an ENCRYPTED non-finite float is still retyped by edit
  (k134)`. Written to pin this defect "so the fix flips it visibly instead
  of quietly", which is what it now does: the subtest is
  `an ENCRYPTED non-finite float is no longer retyped by edit (k134)` and
  asserts the refusal, the untouched wire and `sops edit`'s answer beside it.

### Cost

**None measurable.** A finite float never enters the branch; a non-finite one
pays one flag read and one carrier call, and there are three such values. Best
of seven `emit` runs, alternating between the two libraries:

| document | before | after |
|---|---|---|
| 1000 string leaves | 4.30 – 4.40 ms | 4.38 – 4.95 ms |
| 1000 float leaves | 44.5 – 49.7 ms | 45.0 – 51.4 ms |
| 1000 leaves, one infinity | 3.96 – 4.39 ms | 4.55 – 4.57 ms |

The float row moves in both directions across runs; the spread between repeats
of the *same* library is wider than the difference between the two, which is the
honest reading of a change that adds nothing to the path a finite float takes.

## Consequences

### Wire bytes that move

**No encrypted document's bytes move.** The change is entirely in what a
*plaintext* emit writes, and in one leaf class: a non-finite float with no string
half of its own. In YAML it reaches the file as `.inf` / `-.inf` / `.nan`
instead of `Inf` / `-Inf` / `NaN`, which is what `sops -d` writes for the same
document. In JSON nothing reaches the file, because the call croaks.

The knock-on for the **encrypted** wire is a refusal, not different bytes:
`edit` of such a document now croaks where it used to rewrite the leaf as
`type:str`.

### What changes for existing callers

| input | before | after |
|---|---|---|
| `decrypt_file` of a YAML document with an encrypted `type:float` `+Inf` / `-Inf` / `NaN` | writes `Inf` / `-Inf` / `NaN` | **writes `.inf` / `-.inf` / `.nan`**, byte-identical to `sops -d` |
| `edit` of the same document, editing any key | returns 1, the leaf silently becomes `type:str` | **croak**, naming the key path; the file is untouched and the edit is lost (k122, k123) |
| `decrypt_file` of a **JSON** document with such a leaf | writes `"secret": null` | **croak**, naming the key path — as `sops -d --output-type json` refuses it, exit 4 |
| `edit` of that JSON document | returns 1, the `ENC[...]` is replaced by a bare unencrypted `null` | **croak**; `sops edit` refuses the same document, exit 4 |
| `decrypt` / `extract` of either | the float | **unchanged** — nothing here is on the read path |
| `Format::YAML->emit` called directly with a bare infinity | `Inf` | `.inf` |
| `Format::JSON->emit` called directly with a bare infinity | `null` | **croak** |
| a non-finite float in an **unencrypted** YAML slot, any of ADR 0026's twelve tokens | ADR 0031 and ADR 0034's behaviour | **unchanged**, all 24 rows |
| `dualvar(+Inf, 'banana')` / `'.INf'` / `'-.inf'`, either slot, either format | croak on the encrypt path, its own text on a plaintext emit | **unchanged** |
| a bare `9**9**9` passed to `encrypt` / `encrypt_file` | croak, `assert_representable` | **unchanged** |
| a quoted `".inf"`, a near miss, `1e400`, `007`, `-0.0` | as they were | **unchanged** |

### What this leaves broken, and why it is filed rather than fixed

- **`edit` still cannot save a document with a non-finite float in an encrypted
  slot.** The plaintext now says `.inf`, the reparse now reads it back as the
  float it is — and `Encrypted::encrypt_value` refuses to put a non-finite float
  in an encrypted slot at all (ADR 0031, part 3). So the round trip ends one rung
  higher than it did, loudly instead of silently, and k122 is the rung.
  This change is deliberately shipped without it: turning silent corruption into
  a refusal that names the key path is the same trade ADR 0034 made three commits
  ago for the same leaf class, for the same reason, and with the same ticket
  named as the thing that removes it.

  **And k122's stated premise did not survive this measurement.** ADR 0031
  refused the encrypted slot because "the two formats disagree about it (YAML
  exit 0, JSON exit 4)". Measured here, six documents: `sops -e` writes a JSON
  wire document carrying `type:float` `+Inf` at **exit 0**, and both wire formats
  read back at exit 0 with `--output-type yaml` and at exit 4 with
  `--output-type json`. The disagreement is between **output** formats, which is
  not a property of the document being written — so the format `encrypt_value`
  was said to need may not be needed at all. Recorded on k122; it is a
  decision about an encrypted slot's bytes and it gets its own ADR.

- **A plaintext emit still writes a non-finite float's contradictory string half
  verbatim.** `dualvar(+Inf, 'banana')` reaches a plaintext YAML document as
  `banana` and a plaintext JSON one as `"banana"`. It is refused everywhere a MAC
  is involved, it is unchanged by this decision, and repairing it would mean
  overwriting a string half the caller chose. k140.

- **`edit` destroys the edit whenever the re-encryption refuses.** Untouched
  here, named again because this change adds a case: the temporary file is
  removed on every way out, which the POD documents as a security property.
  ADR 0034 has the argument.

## Rejected alternatives

**Repair the leaf after the reparse instead of at the emit** — key on the text
that comes back from the editor and turn `Inf` into an infinity. It is the
text-keyed repair ADR 0026 rejected, in its worst form: `Inf` is a perfectly
ordinary string that sops reads as a string, and a user who types it means it.
The information is destroyed at the emit; a repair downstream of the destruction
can only guess, and it would guess wrong for every document that really holds
the string.

**Write a marker into the plaintext** — `!!float .inf`, or a comment. It
diverges from what `sops -d` writes, which is a byte-identity ADR 0026
established on purpose and this change extends to the encrypted slot; it shows
the user a document sops would not have written; and `sops -e` normalises the
tag away in any case, so it would not even survive being handed back.

**Put the rule in `Format::YAML`'s carrier, beside the `-0` → `-0.0`
exception.** That is where the *spelling* belongs, and it is where this change
gets the spelling from. It cannot be the whole answer, for the reason the ticket
gives and the measurement confirms: the walk returns before the carrier is
reached, so the handler would have to walk the tree a second time inside `emit`,
and its predicate would be a second copy of `$NO_AGREED_FORM` — one table saying
which floats have no wire form, in two files, drifting.

**Let the leaf take the ordinary `roundtrips` → `carrier` path.** Measured by
ADR 0031 and re-measured here: `roundtrips` reparses with libyaml, libyaml reads
`.inf` back as a string, so it answers no for a leaf that is perfectly writable,
and the carrier is then handed `+Inf` as the text and writes a bare `+Inf` —
which go-yaml reads as a string. The document is `sops -d` exit 0 with the leaf
silently retyped, which is the defect this ADR removes, reintroduced by a
shorter diff.

**Write `".inf"` in JSON rather than refusing.** It preserves the text where
`null` destroys it, and it is still a silent retype: the string comes back from
the editor, `detect_type` says `str`, and the leaf is re-encrypted as `type:str`
— the ticket's own defect, moved to another format. sops refuses the same
document at exit 4 in both places it could produce one, so refusing is the
measured answer and not a conservative choice.

**Refuse in YAML too, for symmetry.** It would make `decrypt_file` refuse a
document `sops -d` writes at exit 0, for a value both implementations can hold
and spell. Symmetry between two formats is not worth a refusal where the
reference succeeds; the formats really are different here, and the emitter is
asked rather than assumed precisely so that the difference is stated once, by
the side that owns it.

**Fix k122 in the same change so the `edit` round trip closes.** It is a
decision about the bytes of an **encrypted** slot, it reopens a refusal ADR 0031
argued for explicitly, and the measurement that reopens it (above) is new. It
deserves its own corpus and its own ADR, and folding it in here would mean
shipping two wire decisions under one argument.
