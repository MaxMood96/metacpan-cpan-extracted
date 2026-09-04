# ADR 0040 — An encrypted slot carries a non-finite float, because sops writes one

- Status: **accepted** — decided and implemented together, in this commit. Every
  table below was measured here against sops 3.13.3 at `/tmp/sops`; the
  candidate fix was built in a scratch copy of `lib/` and measured there, beside
  four other candidates, before anything in the repository changed.
- Date: 2026-08-21
- Tags: float, yaml, json, wire-format, interop, guards, mac
- Resolves k122 and k114. Files k141 (the same question for the
  unencrypted slot) and k142 (what the new predicate call costs) for what
  it deliberately leaves alone.
- **Supersedes part 3 of ADR 0031** — "`encrypt_value` keeps refusing the
  encrypted slot" — and the premise that part rested on. Nothing else in
  ADR 0031 moves: its gate, its twelve-row table, its verdict and its
  unencrypted-slot decision are untouched, and this ADR keeps them for the slot
  they were written for.
- Depends on ADR 0031 (the gate, and the decision this replaces), ADR 0037
  (which turned this round trip's silent corruption into a refusal and named
  this ticket as the rung above it), ADR 0034 (whose repair on **every** parse
  supplies the leaf that closes k114), ADR 0026 (which produces that leaf),
  ADR 0006 (`+Inf` / `-Inf` / `NaN` as a non-finite float's digest text),
  ADR 0012 (a scalar whose two halves disagree is refused, not guessed) and
  ADR 0002 (the type comes from the SV; nothing here reads a leaf's text to
  decide what it is)

## Context

ADR 0031 refused a non-finite float in an **encrypted** slot, explicitly and
with a reason:

> The token is not on the wire there at all — the slot carries `type:float` and
> the plaintext `+Inf` — so the gate says nothing about that document, and the
> two formats disagree about it (YAML exit 0, JSON exit 4) where this method
> cannot tell them apart.

**The second half of that sentence does not hold.** ADR 0037 recorded the
suspicion; this is the re-derivation, done first because the whole shape of the
change depends on it. Six documents, three spellings × two wire formats, each
row a real `sops -e` from the plaintext `secret: .inf`:

| plaintext | `sops -e --output-type yaml` | `sops -e --output-type json` |
|---|---|---|
| `.inf` | exit 0, wire `type:float`, plaintext `+Inf` | **exit 0, wire `type:float`, plaintext `+Inf`** |
| `-.inf` | exit 0, `type:float` | **exit 0, `type:float`** |
| `.nan` | exit 0, `type:float` | **exit 0, `type:float`** |

and reading all six back, twelve rows:

| wire | `sops -d --output-type yaml` | `sops -d --output-type json` |
|---|---|---|
| YAML | exit 0, `secret: .inf` / `-.inf` / `.nan` | exit 4 |
| JSON | exit 0, `secret: .inf` / `-.inf` / `.nan` | exit 4 |

The two **wire** formats behave identically, in both directions. What differs is
the **output** format, which is not a property of the document being written:
Go's JSON marshaller cannot emit a non-finite `float64`, so `sops -d` fails at
the *dump*, after decrypting and after verifying the MAC. The default
`sops -d` on a JSON document is exit 4 only because the output type defaults to
the input type — and **sops produces that document itself**, at exit 0, from a
plaintext it read at exit 0.

So the format `encrypt_value` was said to need is not the fact that decides
this. There is no format-dependent answer to give.

### What the refusal costs

Reproduced at 77e4fdc, sops 3.13.3, `secret` in an encrypted slot, one document
per row, `sops -e` → this library → `sops -d`:

| | `.inf` | `-.inf` | `.nan` |
|---|---|---|---|
| `rotate` | croak | croak | croak |
| `edit` of an unrelated key | croak | croak | croak |
| `decrypt_file` → `encrypt_file` | croak | croak | croak |
| `decrypt` → `encrypt` | croak | croak | croak |

Twelve of twelve, in YAML, on a document `sops -d` reads at exit 0 and
`sops edit` rewrites at exit 0. Since ADR 0037 the `edit` row is a loud refusal
where it used to be a silent retyping to `type:str`; ADR 0037 shipped that
deliberately and named this ticket as the rung that removes it.

### Both gates, and where each slot is knowable

Three scratch copies of `lib/`, one guard bypassed in each, `rotate` of a
sops-written YAML document with an encrypted `.inf`:

| bypassed | result |
|---|---|
| `Encrypted::encrypt_value` only | still croaks, from `assert_representable` |
| `Encrypted::assert_representable` only | still croaks, from `encrypt_value` |
| both | **OK**, `sops -d` exit 0, 3 of 3 |

Two guards, and the reason there are two is that `assert_representable` runs
first, from `_compute_mac`'s leaf sweep, over **every** leaf — encrypted and
unencrypted alike — where `encrypt_value` runs only over the encrypted ones.

The slot is therefore the fact both of them are missing, and it is available in
exactly two places:

- **`encrypt_value` is the encrypted slot by construction.** It exists to put a
  value in one. It does not need to be told.
- **`_compute_mac`'s sweep holds the metadata**, and the encryption rules are
  the metadata's. `$metadata->should_encrypt_path($path)` is the same predicate
  `_encrypt_tree` encrypts by, asked of the same path.

**The emit walk cannot answer it**, and it is worth saying why, because
ADR 0037's carrier question looks like the same question one layer along. By the
time `canonical_float_tree` runs, an encrypted leaf is an `ENC[...]` **string**:
the walk sees the unencrypted slot and nothing else. That is what makes the
carrier the *unencrypted* slot's guard — a good one, and untouched here — and
what makes it structurally unable to be the encrypted slot's.

## Decision

**A non-finite float in an encrypted slot is written, in both formats, as
`type:float` and the plaintext `value_to_bytes` derives from its number — the
bytes sops itself writes for the same value.** Three parts, one of them outside
`Encrypted.pm`:

1. **`assert_representable` takes the slot.** A new named argument, `encrypted`,
   defaulting to false, which is the stricter answer and what every existing
   caller outside this distribution keeps getting. It changes exactly one of the
   three checks — the non-finite float. The reference guard and the `int64`
   guard are slot-blind and stay that way.

2. **`encrypt_value` passes `encrypted => 1`** and its own explicit refusal is
   deleted. The method no longer states a rule of its own about non-finite
   floats; it states which slot it is, and the one gate answers.

3. **`_compute_mac`'s leaf sweep passes `should_encrypt_path`.** One call per
   leaf, the same predicate the encryption walk uses.

### What stays refused in an encrypted slot

A scalar that **states** a string half its number contradicts —
`dualvar(+Inf, 'banana')`, `dualvar(+Inf, '-.inf')`, `dualvar(+Inf, '.INf')`,
and the JSON literal of 400 zeros whose text is its digits (ADR 0020). The wire
is derived from the number, so that text would be dropped without a trace, and
choosing between a scalar's two halves is the guess ADR 0012 refuses to make for
an integer. Six such rows, two formats, all six refused before and after.

That is a deliberately narrower rule than "the encrypted slot ignores the string
half", which is what the slot already does for every other leaf class — measured,
`dualvar(3.14, 'banana')` is written as `type:float` `3.14` and
`dualvar(42, 'banana')` as `type:int` `42`, in an encrypted slot, today. The
inconsistency is real and it is the conservative direction: the leaf that made
it worth keeping is the 401-digit JSON one, where the stated text is the value
the caller can still see and the number is not.

### Why the unencrypted slot is untouched

Because it is a different decision, and it moves ADR 0037's counter-check.

The unconditional variant was built and measured: drop the non-finite refusal
for any leaf with no string half of its own, and the encrypted slot opens
without any slot argument at all — `Encrypted.pm` alone, no `SOPS.pm`, a
one-condition diff. Measured at HEAD, i.e. with ADR 0037's emit repair in place,
it also opens the **unencrypted** YAML cell:

| unencrypted slot, bare NV | before | unconditional variant |
|---|---|---|
| YAML `9**9**9` / `-9**9**9` / `NaN` | croak | **written** `.inf` / `-.inf` / `.nan`, `sops -d` exit 0 |
| JSON, the same three | croak, the guard | croak, the emit walk |

That is a **correct** widening — ADR 0037 gave the emitter a token for exactly
this leaf, and the digest still covers `+Inf` — and it is not this ticket. It
makes writable something a caller can construct and that was refused, which is
the property ADR 0037 stated and pinned in `t/52` section 9; it flips eight
further subtests in four more files; and ADR 0031's measurement of that cell
(`Inf` → `sops -d` exit 51) was taken before the repair existed and no longer
reproduces, which deserves to be said in its own ADR rather than in a paragraph
of this one. k141.

The shipped change moves **no** unencrypted row: 18 of 18 corpus rows in that
slot are identical before and after, croak for croak and document for document.

## What was measured

Every row is a real run against sops 3.13.3 at `/tmp/sops`, before (77e4fdc) and
after (the same tree with this change).

- **A 36-row corpus** — nine leaves (three bare NVs, the three matching
  dualvars, `banana`, `dualvar(+Inf, '-.inf')`, `dualvar(+Inf, '.INf')`) × two
  slots × two formats, each row a real `File::SOPS->encrypt` handed to
  `sops -d` and to `sops -d --output-type yaml`. **12 rows move**, all of them
  in the encrypted slot: croak → written, `type:float`, `sops -d` exit 0 in
  YAML and exit 0 under `--output-type yaml` in JSON. The other 24 are
  identical, including all 18 unencrypted ones and the six encrypted
  contradictions.
- **The four round trips**, three spellings × two formats, `sops -e` → this
  library → `sops -d`:

  | | YAML before | YAML after | JSON before | JSON after |
  |---|---|---|---|---|
  | `rotate` | 0/3 | **3/3 exit 0** | 0/3 | **3/3**, exit 0 under `--output-type yaml` |
  | `edit` of another key | 0/3 | **3/3 exit 0**, the edit applied | 0/3 | 0/3 — refused at the plaintext emit (ADR 0037), as `sops edit` is exit 4 |
  | `decrypt_file` → `encrypt_file` | 0/3 | **3/3 exit 0** | 0/3 | 0/3, same refusal |
  | `decrypt` → `encrypt` | 0/3 | **3/3 exit 0** | 0/3 | **3/3** |

- **k114's own corpus**, all twelve `%GO_CONSTANT` spellings, plaintext
  `secret: <token>` with `secret` in an encrypted slot, `encrypt_file` handed to
  `sops -d --output-type yaml`, beside `sops -e` on the identical plaintext:
  **0 of 12 → 12 of 12**, `type:float` in every row, and `sops -d` prints the
  same normalised token for our document as for sops's own. That ticket's
  divergence — `type:str` here, `type:float` to sops — is gone, in every row.
- **The encryption rules decide the slot, not the default suffix**: with
  `encrypted_regex => '^sec'`, `encrypted_suffix => '_enc'` and
  `unencrypted_regex => '^pub'`, the leaf the rule encrypts is written and the
  leaf it does not is refused — six rows, three rules, both directions.
- **`mac_only_encrypted`**, both formats: written, `sops -d` exit 0 in YAML and
  under `--output-type yaml` in JSON, no warning.
- **Nested**: an infinity as an array element and three levels down a hash,
  both formats, two `type:float` leaves per document, `sops -d --output-type
  yaml` exit 0 with both leaves correct.
- **The read side does not move.** `decrypt` of our own document hands back the
  infinity as a **bare NV** — `SVf_NOK` set, `SVf_POK` clear — in both formats,
  which is what ADR 0009 and ADR 0010 require and what k114 measured for
  sops's own document.
- **ADR 0037's twelve-row encrypt-path counter-check** (`t/52` section 9, seven
  leaves × two formats over the unencrypted slot): **identical before and
  after**, message for message. It is the reason the unencrypted slot is not in
  this change.
- `prove -lr t/` was **1172/1172 at 77e4fdc** (53 files) and is **1189/1189**
  (54 files) with the new file and the eight replaced claims below — measured on
  a tree carrying this change and nothing else, because another lane's work
  (`Format::YAML`, `t/53`) was landing beside it; with that in the tree too the
  suite is 1199/1199 over 55 files.
  `SOPS_BIN=/tmp/sops prove -lv t/04-interop.t` is **32/32, executed rather than
  skipped**, before and after.
- **Counter-check:** `t/54-an-encrypted-non-finite-float-is-written.t` run
  against the unpatched 77e4fdc with `perl -I` and no `use lib` in the file —
  **12 of its 17 subtests and 88 of its 240 assertions fail**, and every one of
  the five that pass is a must-not-move section: the unencrypted slot's own
  answers (ADR 0037's counter-check), the 401-digit JSON literal, the JSON
  plaintext refusal beside `sops edit`'s exit 4, and the two sections that are
  nothing but `sops` itself — the premise this decision rests on, which has to
  read the same either way.

### The eight claims this replaces

Every one of them pins the refusal this ticket exists to remove, and every one
is edited in place rather than deleted, in the same shape the earlier lanes used
for `t/46`, `t/49`, `t/42` and `t/39`:

- **`t/39` section 11**, `a real non-finite float is still refused`. It asserted
  the refusal for `v` and `v_unencrypted` together. The section's point — that
  ADR 0023 removed a parser artefact and did not loosen a rule about values — is
  about the unencrypted slot, which still answers exactly as it did; the `v` half
  now asserts the encrypted slot's document.
- **`t/46` section 5**, `a bare non-finite float is refused in every slot and
  format`. Same shape: the two unencrypted cells are unchanged, the two encrypted
  ones now carry the value.
- **`t/46` section 6**, `an encrypted slot still refuses every non-finite float`,
  and **section 7**, `encrypt_value refuses it directly, format-blind`. Both are
  k122 stated as a test. They now assert what `encrypt_value` writes, and
  that it still refuses a stated contradictory string half.
- **`t/49` section 4**, `an encrypted slot is refused, naming the key path` —
  ADR 0034's one row where this library refused something sops writes. It is
  now written, and the subtest asserts the `type:float` and sops's own reading
  of it.
- **`t/49` section 16**, `an ENCRYPTED non-finite float is no longer retyped by
  edit (k134)`. ADR 0037 turned the silent retyping into a refusal and said
  so in the name; the refusal is now a completed edit, and the subtest asserts
  the wire beside `sops edit`'s own answer.
- **`t/52` section 10**, `and an encrypted slot is still refused, in both
  formats`, and **section 12**, `edit refuses instead of retyping, and leaves the
  wire alone`. The same two rows from ADR 0037's own file, which named k122
  in both.

## Cost

**One `should_encrypt_path` call per leaf in the MAC sweep**, and nothing
anywhere else. Measured, best of seven, alternating between the two libraries:

| document | before | after |
|---|---|---|
| `encrypt`, 1000 string leaves | 41.4 – 42.0 ms | 42.9 – 43.5 ms |
| `encrypt`, 2000 leaves, half of them floats | 94.8 – 99.3 ms | 99.4 – 101.5 ms |

That is about 4% on a thousand-leaf document and 1.9 µs per leaf, and it is
entirely the one call: a variant passing a constant instead runs at or below the
unpatched library (40.4 – 41.5 ms). The predicate itself is 1.87 µs, of which
only ~0.12 µs is the regex interpolation — the rest is the method call and four
`defined && length` accessor pairs. `_encrypt_tree` already pays it once per
leaf, so a thousand-leaf document now pays it twice; that is k142, in the
lane that owns `Metadata.pm`.

The lazy alternative was built and **measured slower than the call it avoids**:
passing `encrypted` as a coderef so the sweep only computes the answer for a
leaf that needs one costs 43.7 – 45.1 ms / 101 – 113 ms, because a closure per
call is dearer than the predicate. The straight boolean is what ships.

## Consequences

### Wire bytes that move

One document class, and only where it could not be written at all before: a
non-finite float in an **encrypted** slot now reaches the wire as `type:float`
with the plaintext `+Inf` / `-Inf` / `NaN`, in YAML and in JSON. That is what
`sops -e` writes for the same value in the same slot, in both formats.

No unencrypted slot's bytes change. No document this library could write before
is written differently.

### What changes for existing callers

| input | before | after |
|---|---|---|
| `rotate` of a sops-written YAML document with an encrypted `.inf` / `-.inf` / `.nan` | croak | **written**, `sops -d` exit 0, the leaf still `type:float` |
| `edit` of the same document, editing any key | croak (ADR 0037), the edit destroyed | **written**, the edit applied, `sops -d` exit 0 |
| `decrypt_file` → `encrypt_file` of the same | croak | **round-trips** |
| `decrypt` → `encrypt` of the same, in memory | croak | **round-trips** |
| the same four on a **JSON** wire document | croak | `rotate` and the in-memory pair are **written**; `edit` and `decrypt_file` still croak at the plaintext emit, where `sops edit` and `sops -d --output-type json` are exit 4 |
| `encrypt_file` of a **plaintext** whose encrypted slot holds any of the twelve tokens | croak (ADR 0034's one row where sops succeeds) | **written as `type:float`**, 12 of 12, identical to what `sops -e` writes — k114 |
| `encrypt(data => { secret => 9**9**9 })`, either format | croak | **written**, `type:float` |
| `dualvar(+Inf, 'banana')` / `'.INf'` / `'-.inf'` in an encrypted slot | croak | **croak**, in a message about the two halves rather than about the float |
| a non-finite float in an **unencrypted** slot, any spelling, either format | ADR 0031 and ADR 0037's behaviour | **unchanged**, all 18 rows |
| the 401-digit JSON literal, either slot | croak | **unchanged** — its digits are a stated string half |
| `decrypt` / `extract` of any of these | the float, as a bare NV | **unchanged** — nothing here is on the read path |
| `assert_representable($v)` called directly | as it was | **unchanged** — `encrypted` defaults to false |
| everything else | | untouched: the 1172 assertions at 77e4fdc all still pass |

A JSON document written this way is `sops -d` exit 4 by default, and that is
worth stating plainly rather than burying: it is the same exit 4
`sops -e --output-type json` produces for its own output, the MAC verifies, and
`sops -d --output-type yaml` reads it at exit 0. Refusing it would have been a
refusal where the reference succeeds, on a document the reference itself writes.

### What this leaves broken, and why it is filed rather than fixed

- **A bare non-finite float in an unencrypted YAML slot is still refused**,
  where the emit walk would now write it correctly. Measured above; k141,
  its own ADR.
- **`edit` and `decrypt_file` of a JSON document with such a leaf still
  refuse.** They have to write a plaintext, JSON has no spelling for a
  non-finite number, and ADR 0037 decided that refusing is the measured answer —
  `sops edit` is exit 4 on the same document. Unchanged here.
- **`should_encrypt_path` is now asked twice per leaf on the encrypt path.**
  k142.
- **`edit` destroys the edit whenever the re-encryption refuses.** Untouched,
  and this change removes causes rather than adding any. ADR 0034 has the
  argument.

## Rejected alternatives

**Give `encrypt_value` the document format** — k122's own plan, and
ADR 0031's. It was measured out of existence before it was built: both wire
formats carry this leaf at exit 0, the disagreement is between *output* formats,
and an output format is not a property of the document being written. Building
it would have threaded an argument through `_encrypt_tree` to answer a question
nobody is asking.

**Refuse in JSON and write in YAML anyway**, for safety. It refuses a document
`sops -e --output-type json` writes at exit 0, whose MAC verifies and which
`sops -d --output-type yaml` reads. It would also make `rotate` of such a
document impossible in the one format where the user is most stuck: the file
they already have is exit 4 on a default `sops -d` whether we touch it or not.

**Open the gate unconditionally**, with no slot at all. Smaller — one condition,
`Encrypted.pm` alone, no `SOPS.pm`. Measured and tabled above: it also makes a
bare non-finite float writable in an **unencrypted** YAML slot. That is
probably right and it is a different ticket, because it moves ADR 0037's own
counter-check table, which this change is measured against. k141.

**Skip the non-finite check for an encrypted slot entirely**, rather than
narrowing it to the stated contradiction. Simpler, one word, and consistent with
what the encrypted slot already does with a `dualvar(42, 'banana')`. Measured
wrong for one leaf class: the JSON literal of 400 zeros arrives as `+Inf`
carrying its own digits (ADR 0020), and this variant writes it as `type:float`
`+Inf` with the digits gone — a caller's value silently replaced by infinity,
which is the defect class this layer exists to prevent. `t/36` section 8 caught
it, and the section is right.

**Pass `encrypted` as a coderef so the sweep computes it lazily.** Built and
benchmarked: slower than the call it avoids, in both document shapes, because a
closure per leaf costs more than `should_encrypt_path`. It would also have put a
callback into a public method's signature for a saving that is not there.

**Move the unencrypted slot's non-finite check into `_encrypt_tree`**, which
already has `should_encrypt_path` computed and would make the new call free. It
puts the refusal after the digest and inside a walk that iterates a hash in
Perl's randomised key order, so which of two bad leaves is named would stop
being deterministic — `_compute_mac`'s sweep is sorted, and that is worth more
than 1.9 µs a leaf.

**Have the decrypt side hand back `dualvar($double, $token)` for an encrypted
`type:float`**, so the leaf arrives at re-encryption already carrying a token and
ADR 0031's gate lets it through unchanged. It needs the format at the decrypt,
which is no more available there than at the encrypt; it changes what `decrypt`
and `extract` return to every caller, which ADR 0009 and ADR 0010 pin as a bare
NV; and the token would be a fiction — the encrypted slot never held one.
