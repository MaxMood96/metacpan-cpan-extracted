# ADR 0031 — A non-finite float that carries go-yaml's own token is written

- Status: **accepted** — decided and implemented together, in this commit. Every
  table below was measured here against sops 3.13.3 at `/tmp/sops`, with the
  k59 guard bypassed **in a scratch copy of `lib/`** and no code in the
  repository changed until the tables existed.
- Date: 2026-08-21
- Tags: float, yaml, json, wire-format, interop, guards, mac
- Resolves k113. Files k122 (the encrypted slot) and k123
  (`edit`) for what it deliberately leaves alone.
- Depends on ADR 0013 (the foreign-resolution guard, whose model of `resolve.go`
  is the **verdict** this decision defers to), ADR 0017 (that guard answers from
  the token the emitter writes), ADR 0026 (which produces the scalar shape this
  is about), ADR 0012 (a scalar whose two halves disagree is refused, not
  guessed), ADR 0006 (a written decimal has to parse back to the same double)
  and ADR 0002 (the type comes from the SV; nothing here numifies a string or
  stringifies a number)

## Context

Since ADR 0026 this library **reads** a YAML document that sops wrote with a
bare `.inf` in an unencrypted slot: the parse hands back a `dualvar` carrying
the double go-yaml resolves and the token the document holds, and the MAC
verifies. It could not **write** that document back. Measured at 5536313, one
document per row, sops 3.13.3:

| step | `.inf` | `-.inf` | `.nan` |
|---|---|---|---|
| `sops -e` | exit 0, wire `.inf` | exit 0, wire `-.inf` | exit 0, wire `.nan` |
| `File::SOPS->decrypt` | reads it | reads it | reads it |
| `File::SOPS->rotate` | **croak** | **croak** | **croak** |

The croak is k59's non-finite guard in `Encrypted::assert_representable`,
reached through `_compute_mac`'s leaf sweep. So the library had a document class
it could read and not write — and the advice in the message ("store the value as
a string") leads straight back to ADR 0013's refusal, because the string `.inf`
is written bare in YAML and Go reads a float out of it.

### The guard's premise, and where it stops holding

k59 refuses every non-finite float on the encrypt path because
`value_to_bytes` writes `+Inf` / `-Inf` / `NaN` — Go's `strconv.FormatFloat`
text, and what the digest covers — while the emitters write something else for
the same double. Re-measured here, unencrypted YAML slot, one document per row:

| leaf | document | Go digests | `sops -d` |
|---|---|---|---|
| bare `9**9**9` | `Inf` | `Inf` | **exit 51** |
| bare `-9**9**9` | `-Inf` | `-Inf` | exit 0, **read back as a string** |
| bare `NaN` | `NaN` | `NaN` | exit 0, **read back as a string** |
| `dualvar(+Inf, '.inf')` | `.inf` | `+Inf` | **exit 0, read back as a float** |

The premise holds for a bare NV — and the two exit-0 rows are worse than the
exit-51 one, not better: the file verifies while the leaf has silently stopped
being a number. It does **not** hold for the fourth row, which is the shape
ADR 0026 produces. There the document says what sops itself would have written
and the digest covers what sops itself would have digested.

The full corpus, twelve `%GO_CONSTANT` tokens as `dualvar($double, $token)`,
two slots, two formats, 48 documents, guard bypassed:

| format | slot | `sops -d` |
|---|---|---|
| YAML | unencrypted | **12 of 12 exit 0**, value and spelling correct |
| YAML | encrypted | 12 of 12 exit 0 (`type:float`, plaintext `+Inf`) |
| JSON | unencrypted | **12 of 12 exit 51** — Cpanel writes `".inf"`, a quoted string, and the digest covers `+Inf` |
| JSON | encrypted | **12 of 12 exit 4** — `Error marshaling to json: Error encoding value`; Go cannot marshal a non-finite `float64` at all |

And the round trip that is the point of the ticket, guard bypassed:
`sops -e` → `File::SOPS->rotate` → `sops -d` is **exit 0 for all three
spellings sops writes**, with the wire byte-identical to what sops put there.

### So the answer is format-specific, and the guard is format-blind

`assert_representable` is reached from `File::SOPS::_compute_mac` (every leaf,
unencrypted included) and from `Encrypted::encrypt_value` (encrypted leaves).
Neither knows the format, and neither can: the format is known in `File::SOPS`
and nowhere below it. A format-blind exemption opens **both** JSON cells at
once, and k62 is this distribution's own record of what that costs — a fix measured
for YAML that would have taken JSON with it.

The JSON unencrypted cell is the dangerous one: the file is written **silently**
and fails its own MAC on the next read, by anyone. That is the exact defect
class this layer exists to prevent, so any decision that opens it is not
available.

## Decision

**A non-finite float is refused unless it carries, as its own public string
half, a plain token a foreign YAML reader resolves back to exactly that double —
and that check is a GATE, whose VERDICT belongs to the emitter's
foreign-resolution guard.** Three parts, all in
`lib/File/SOPS/Encrypted.pm`:

1. **`assert_representable` gates.** `_carries_go_non_finite_token` asks two
   things and both have to answer yes: the scalar publishes `SVf_POK` (the
   public flag, for the reason `_has_public_pv` gives — printing a float sets
   the private one), and `_go_non_finite_token_bytes` maps its text to the same
   bytes `value_to_bytes` derives from its number. A `dualvar(+Inf, '-.inf')` is
   a contradiction and stays refused, the same answer ADR 0012 gives an integer
   whose halves disagree. A bare NV, a computed overflow and a JSON `1e400` are
   refused exactly as before, with the message extended to say what the other
   answer is.

2. **`canonical_float_tree` hands the leaf to the verdict.** A non-finite leaf
   carrying such a token no longer leaves the walk unchecked: where the handler
   installed a `reject_scalar` (the YAML handler does, for every MAC-covered
   document — ADR 0013 and ADR 0018) the leaf goes through it, and that guard
   compares the token **the emitter actually writes** against `_go_scalar_bytes`,
   the one model of `resolve.go`. Where the document carries a MAC and the
   handler installed no such guard — which is JSON, whose `emit` is the identical
   call on both paths — the leaf is **refused**, naming the key path. A document
   with no MAC keeps today's behaviour exactly: the plaintext emitters go on
   writing `.inf`, and `decrypt_file` still reproduces sops's own plaintext byte
   for byte.

3. **`encrypt_value` keeps refusing the encrypted slot**, explicitly rather than
   as a side effect of the gate. The token is not on the wire there at all —
   the slot carries `type:float` and the plaintext `+Inf` — so the gate says
   nothing about that document, and the two formats disagree about it (YAML exit
   0, JSON exit 4) where this method cannot tell them apart. Filed as k122.

### Why the gate has to be tight, and why it is not the verdict

Both halves were measured, and each answers one obvious simplification.

**"Just require a public PV and let ADR 0013's guard decide"** — measured
against the guard itself:

| leaf | digest covers | `_reject_foreign_resolution` |
|---|---|---|
| `dualvar(+Inf, '.inf')` | `+Inf` | accepted |
| `dualvar(+Inf, '-.inf')` | `+Inf` | refused |
| `dualvar(-Inf, '.inf')` | `-Inf` | refused |
| `dualvar(+Inf, '.INf')` | `+Inf` | refused |
| `dualvar(+Inf, 'banana')` | `+Inf` | **accepted** |

The last row is why. That guard's gate is `_go_might_look_at`, and Go's resolver
does not look at a token starting with `b`; the guard is sound for every leaf
class it was written for because by the time it runs, a float leaf's emitted
token **is** the text the digest covers (ADR 0011's carrier saw to that). A
non-finite leaf is the one that never goes through the carrier, so it is the one
that can arrive with a token nobody checked. Measured, `dualvar(+Inf, 'banana')`
in an unencrypted YAML slot is `sops -d` exit 51.

**"Then put the whole check here and skip the guard"** — the gate would become a
second copy of Go's resolution model beside `_go_scalar_bytes`, which is this
distribution's signature defect, and it would answer about the leaf's PV rather
than about the bytes `YAML::XS` writes for it, which is the distinction ADR 0017
exists to keep (k90 came through exactly that gap).

So the gate states twelve rows of Go's `resolveMap` a second time, and that is a
deliberate, bounded duplication with an argument attached: **both drift
directions fail closed.** A row here that `%GO_CONSTANT` lacks is refused by the
guard on bytes; a row `%GO_CONSTANT` gains that is missing here is refused by
this gate. Neither can put a file on disk, which is the property the single-copy
rule protects. The verdict — what Go makes of a token — stays in one place.

### Why the walk asks the tree whether the document carries a MAC

`_document_carries_mac` reads a top-level `sops` key off the tree
`canonical_float_tree` was handed. It is a fact about the document and the only
signal available at that point: a handler's `serialize` adds the metadata under
`sops` before calling its emitter, and the plaintext emitters hand over the tree
without one. The YAML handler additionally says so by installing a
`reject_scalar`; the JSON handler's `emit` is the **identical call** on both
paths, so for JSON there is nothing else to read. It is the same fact ADR 0026's
parse-side walk keys on, read from the same place.

It cannot answer wrongly in the direction that matters: `serialize` always adds
the key and refuses a tree that already has one, and a multi-document stream is
refused one layer up, so the root is the single document's hash. The one
reachable false answer is a caller invoking a handler's public `emit` on a
plaintext tree that happens to have a top-level `sops` key — and there the leaf
is refused where it would have been written, which is the harmless direction.

### What was measured

- **The 48-row corpus above**, twelve tokens × two slots × two formats, each row
  a real `File::SOPS->encrypt` handed to `sops -d`, before (guard bypassed) and
  after. After: the 12 YAML unencrypted rows are exit 0 and byte-identical to
  the bypassed run; the other 36 croak, naming the key path, and put no file on
  disk.
- **The round trip**, `sops -e` → `File::SOPS->rotate` → `sops -d`, for the three
  spellings `sops -e` actually writes: **3 of 3 exit 0**, wire byte-identical,
  where all three croaked before.
- **A 36-row refusal corpus** — three bare NVs and six mismatched or near-miss
  dualvars (`banana`, `.INf`, `-.inf` on a `+Inf`, `.inf` on a `-Inf`, `.inf` on
  a `NaN`, `+Inf` on a `+Inf`) × two slots × two formats. Every one of them was
  refused before this change and is refused after it. Nine of those rows were
  `sops -d` exit 0 with the guard bypassed, and each of those nine had silently
  retyped the leaf from a float to a string — which is why they stay refused
  rather than being repaired.
- **ADR 0013's guard as a second line of defence**, called directly on five
  leaves: it accepts the matching token, refuses all three contradictions and
  the near miss, and accepts `banana` — the row that decides how tight the gate
  has to be.
- `prove -lr t/` was 1062/1062 at 5536313 and is **1080/1080** with the new file
  and the two replaced claims in `t/42` (47 files; the suite is 1100/1100 with
  the two files that landed from other lanes while this was measured, and no
  existing test was edited beyond those two claims).
  `SOPS_BIN=/tmp/sops prove -l t/04-interop.t` is **32/32, executed rather than
  skipped**, before and after.
- Counter-check: `t/46-non-finite-token-is-written.t` run against the unpatched
  5536313 with `perl -I` and no `use lib` in the file — **8 of its 17 subtests
  and 40 assertions fail**, and the nine subtests that pass are the must-not-move
  ones (the contradictions, the bare NVs, the JSON refusal and the reason for it,
  the plaintext walk, `decrypt_file`). Six of the 40 are message assertions on a
  refusal that is itself unchanged — the encrypted slot, which now says so in its
  own words; the other 34 are behaviour.

### Cost

**4% on `encrypt_value` for a float leaf**, and nothing anywhere else. Measured,
best of seven runs, alternating between the two libraries: 50.0 ms → 52.0 ms per
2000 calls, i.e. about a microsecond per encrypted float, for the three numeric
comparisons `encrypt_value` now makes before it converts anything.

The first draft cost **100%** — 130 ms → 272 ms per 5000 calls — because the
non-finite question was asked through `_float_bytes`, whose shortest-round-trip
loop runs up to seventeen `sprintf`s for a finite float. That is a tax on every
encrypted float in every document, for a guard about three values, and the fix
was to invert the two: `_non_finite_bytes` decides in three comparisons, and
`_float_bytes` calls **it** rather than the other way round, so the rule is
still stated once and the loop is still only reached by a float that needs it.

`canonical_float_tree` gains one hash lookup per walk (`exists $tree->{sops}`)
and one more argument through a walk that already carried six; the string half
is read only for a leaf already known to be non-finite, of which three exist.

## Consequences

### Wire bytes that move

One document class, and only where it could not be written at all before: an
unencrypted YAML slot holding a `%GO_CONSTANT` token now reaches the document as
that token, with the digest covering `+Inf` / `-Inf` / `NaN`. That is what sops
writes and what sops digests for the same document.

Nothing else moves. No document this library could write before is written
differently.

### What changes for existing callers

| input | before | after |
|---|---|---|
| `rotate` / `encrypt` of a sops-written YAML document with a bare `.inf` / `-.inf` / `.nan` in an **unencrypted** slot | croak, the non-finite guard | **written**, `sops -d` exit 0, wire byte-identical |
| the same, hand-built as `dualvar($double, $token)` for any of the twelve spellings | croak | written |
| the same value in a **JSON** document, either slot | croak, the non-finite guard | croak — the unencrypted slot now from the walk, naming the key path and saying JSON has no spelling |
| a **bare** `9**9**9`, a computed overflow, a JSON `1e400` | croak | **unchanged**, same guard, message extended with the second answer |
| `dualvar(+Inf, '-.inf')`, `dualvar(-Inf, '.inf')`, `dualvar(+Inf, '.INf')`, `dualvar(+Inf, 'banana')` | croak | **unchanged** — refused by the gate, and the first three again by ADR 0013's guard if they ever reach it |
| a non-finite float in an **encrypted** slot, either format | croak | **unchanged** — refused by `encrypt_value` now, with a message that says a YAML document can carry it unencrypted (k122) |
| `decrypt_file` of a document with a repaired `.inf` | writes `v_unencrypted: .inf` | **unchanged** |
| `edit` of such a document, with a real change | croak, ADR 0013's guard | **unchanged** — the leaf loses its float-ness in the plaintext round trip through the editor, which is a different defect (k123) |
| everything else | | untouched: the 1062 assertions at 5536313 all still pass |

### What this leaves broken, and why it is filed rather than fixed

- **`edit` still cannot save such a document.** It decrypts to a plaintext
  document and reparses what the editor hands back, and ADR 0026's repair walk
  deliberately does not run on a plaintext document, so the leaf returns as the
  string `.inf` and ADR 0013's guard refuses it — correctly, for what it sees.
  Measured identical with this change and without it. k123, format lane.
- **The encrypted slot stays refused in YAML**, where measured it would have
  worked in all twelve rows. It needs the format at the leaf, which reaches
  neither `encrypt_value` nor `assert_representable`. k122.
- **JSON has no scalar-level guard of its own.** The refusal this adds lives in
  the format-blind walk and speaks for it; the place it belongs is a
  `reject_scalar` in `Format::JSON`, which is another lane's file and was
  outside this change's boundary. When that exists, the walk's own refusal
  becomes unreachable rather than wrong.

## Rejected alternatives

**Leave the guard alone and document the divergence.** It makes permanent a
document class this library reads and cannot write, for a distribution whose
whole claim is byte compatibility — and the document in question is one sops
writes by default from a plaintext `.inf`.

**Put the check in `Format::YAML`, beside ADR 0013's** — k113's own
suggestion, and where the *verdict* does live. It cannot be the whole answer:
`assert_representable` runs first, from `_compute_mac`'s sweep, and refuses the
leaf before any emitter sees it. Something in the format-blind layer has to stop
refusing before a format-specific check can ever be reached. What is left for
`Format::YAML` — a `reject_scalar` that already handles this leaf correctly — is
already there.

**Exempt any non-finite float that carries a public PV.** Twenty characters,
and measured wrong: `dualvar(+Inf, 'banana')` is accepted by ADR 0013's guard
(its gate never looks at a `b`) and produces an unencrypted YAML document that
is `sops -d` exit 51. The gate has to name the tokens.

**Let the float carrier deal with it** — remove the `NO_AGREED_FORM`
short-circuit and send the leaf down the ordinary `roundtrips` → `carrier` path,
the way k62 solved the negative zero. Measured, and it is the trap it looks
like: `roundtrips` reparses with **libyaml**, which reads `.inf` back as a
string, so it answers "no" for a leaf that is perfectly writable; the YAML
carrier then replaces the document's own `.inf` with `dualvar(+Inf, '+Inf')`,
which writes a bare `+Inf`. That document is `sops -d` **exit 0** — and the leaf
has silently become a string in both implementations. The JSON carrier croaks on
the same input, from an assertion about `Math::BigFloat` accuracy that has
nothing to do with the case. A local reparse cannot answer a question about a
foreign resolver, which is ADR 0013's founding observation.

**Refuse in the walk whenever no `reject_scalar` was installed, without asking
whether the document carries a MAC.** One line shorter, and it refuses
`decrypt_file` and `edit` on every document ADR 0026 taught this library to
read — the plaintext emitters install no guard because they need none.

**Ask `YAML::PP` whether the token resolves.** It is the oracle ADR 0026 uses,
and it answers a question about **bytes in a document**. Here there is no
document yet: the question is what an emitter is about to write and what a
foreign reader will make of it, and ADR 0013 already answers that, for this
token class as for every other.

**Widen `%GO_CONSTANT`'s home to `Encrypted.pm` so there is one table.** The
right shape, and the wrong change to make from here: `Format::YAML` derives four
things from that table, and moving it means editing a file another lane is
working in. The duplication this leaves is twelve rows in a gate that fails
closed in both directions; the verdict is not duplicated at all.
