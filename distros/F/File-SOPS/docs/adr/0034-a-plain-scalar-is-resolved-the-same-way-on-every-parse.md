# ADR 0034 — A plain scalar is resolved the same way on every parse

- Status: **accepted** — decided and implemented together, in this commit. Every
  table below was measured here against sops 3.13.3 at `/tmp/sops`; the
  candidate fix was built in a scratch copy of `lib/` and measured there before
  anything in the repository changed.
- Date: 2026-08-21
- Tags: yaml, float, editor, parser, interop, mac
- Resolves k123. Files k134 (the encrypted slot's plaintext spelling)
  and k135 (a string leaf libyaml leaves bare) for what it deliberately
  leaves alone.
- **Supersedes one decision in ADR 0026** — its "Run the walk on plaintext
  documents too, for symmetry" rejection — and nothing else in it. The repair
  itself, its oracle, its dualvar and its `%GO_CONSTANT` table are untouched.
- Depends on ADR 0026 (which produced the repair and the gate this removes),
  ADR 0031 (which removed the gate's premise), ADR 0013 and ADR 0017 (the
  foreign-resolution guard, still the verdict on the write side), ADR 0023
  (whose walk runs first over the same tree) and ADR 0002 (the type comes from
  the SV; nothing here reads a leaf's text to decide what it is)

## Context

ADR 0026 taught `Format::YAML::parse` to hand back `dualvar($double, $token)`
for a scalar the **document wrote plain** whose token go-yaml resolves to a
non-finite float, and gated that repair on the document carrying a `sops:`
section. The gate's argument, quoted from its own "Rejected alternatives":

> A worse message for no gain, since neither path can write the document.

Both halves have since stopped being true, and the second one stopped being
true in this repository, three commits ago.

**ADR 0031 made the document writable.** An unencrypted YAML slot holding one
of the twelve tokens now reaches the file as that token, with the digest
covering `+Inf` / `-Inf` / `NaN`. So the gate was not choosing between two
errors any more; it was choosing an error over a document.

**And the two parses disagreed about identical bytes.** Measured at 0da0170,
one document per row, sops 3.13.3:

| step | `.inf` | `-.inf` | `.nan` |
|---|---|---|---|
| `sops -e` | exit 0, wire `.inf` | exit 0, wire `-.inf` | exit 0, wire `.nan` |
| `File::SOPS->decrypt_file` | writes `v_unencrypted: .inf` | `-.inf` | `.nan` |
| `File::SOPS->encrypt_file` **of that same file** | **croak** | **croak** | **croak** |

This library wrote a plaintext its own reader refused. The bytes are the ones
`sops -d` writes, byte for byte — that byte-identity is ADR 0026's own stated
achievement — and handing them back to `encrypt_file` produced ADR 0013's
foreign-resolution refusal, which named the key path and advised passing a
decimal or encrypting the leaf. Neither is the answer: the answer is that the
document already says what it means.

### What k123 measured: `edit`

`edit` decrypts to a plaintext, hands it to an editor, and reparses what comes
back. With the gate on, the leaf came back as the string `.inf` and ADR 0013's
guard refused it — correctly, for what it saw. Measured at 0da0170, `$EDITOR` a
script that changes an unrelated key and exits 0:

| document | `File::SOPS->edit` | `sops edit`, same document, same editor |
|---|---|---|
| sops-written, bare `.inf` in an unencrypted slot | **croak** | exit 0, wire unchanged, `sops -d` exit 0 |
| the same with `-.inf` | **croak** | exit 0 |
| the same with `.nan` | **croak** | exit 0 |

**And the edit is destroyed.** `_edit_text` scopes the plaintext to a
`File::Temp` directory that goes out of scope when it returns, which is
*before* the re-encryption runs. Measured: the editor's file is gone by the
time the croak reaches the caller, directory and all. So a user who opens a
sops-written document, changes a completely unrelated key and saves loses
everything they typed — and the leaf they lost it over is one they never
touched and may not have known was there. That is what decided the priority of
this ticket: it is not an error-message defect.

### The reference has one parse

sops does not distinguish a plaintext from a wire document when it resolves a
scalar, and the measurement says so from both sides. `sops -e` on a plaintext
`v_unencrypted: .inf` writes a document whose MAC covers `+Inf`; `sops edit`
reparses the editor's output with the same resolver and keeps the leaf a float.
There is no second, gentler parse for text sops wrote itself, and the file it
writes is the same either way.

### What the ticket proposed, and why it is not what shipped

k123 suggests the plaintext `edit` reparses "is one this library WROTE
from a document it had already resolved, which is a different case and may
deserve a different answer — possibly a marker on the way out rather than a
re-guess on the way in".

There is nothing to mark and nothing to re-guess. The plaintext `decrypt_file`
and `edit` write is `v_unencrypted: .inf` — a **plain** scalar, which is the
entire fact ADR 0026's oracle asks about. The information the round trip was
said to lose was never lost; it was in the bytes the whole time, and the parse
was declining to look. A marker would also not survive the one thing the
document is handed to an editor *for*: the user can retype the line, move it,
or copy it in from elsewhere, and `sops edit` handles all three.

## Decision

**`Format::YAML::parse` runs ADR 0026's repair on every document, whether or
not it carried a `sops:` section.** One line: the `if $metadata` gate is gone.

Nothing else about the repair changes — not the two cheap gates, not the
`YAML::PP` oracle, not `%GO_CONSTANT`, not the dualvar, not the fail-safe, and
not the order relative to ADR 0023's walk. Its guarantee is the same one it
always had, stated once instead of twice: **a scalar this document wrote plain
means what go-yaml makes of it.**

`edit` needs no argument, `parse` needs no flag, and `Format::JSON` needs
nothing at all — `.inf` is not JSON, so no token can reach a JSON document in
the first place.

### Why not a flag from `edit`

The obvious narrow fix is `edit` passing `resolve_plain_scalars => 1` into its
reparse, leaving a foreign plaintext on ADR 0026's gate. It was built and
measured first, in a scratch `lib/`, and it works for the ticket's own rows. It
was rejected for what it does to the rest of the API:

| plaintext, unencrypted slot | `edit` | `encrypt_file` |
|---|---|---|
| flag from `edit` | written | **croak** |
| gate removed | written | written |

| plaintext, encrypted slot | `edit` | `encrypt_file` |
|---|---|---|
| flag from `edit` | **croak** | written, `type:str` |
| gate removed | croak | croak |

Two public methods of one class, handed the identical bytes, answering
oppositely — in both directions at once. It also leaves the `decrypt_file` →
`encrypt_file` round trip broken, which has no editor in it and is the row that
made the gate indefensible. A flag would have been a second rule to keep true,
bought with a smaller diff.

### What this costs, deliberately

**A bare token under a key that gets encrypted is now refused where it used to
be written.** Measured, plaintext `secret: .inf` with `secret` in an encrypted
slot:

| | wire | `sops -d` |
|---|---|---|
| `sops -e` | `type:float`, plaintext `+Inf` | `secret: .inf` |
| this library, before | `type:str`, plaintext `.inf` | `secret: ".inf"` |
| this library, after | croak, naming the key path | — |

The old row is a working file whose value has silently stopped being a number:
`.inf` went in and a quoted string came out, and sops agrees with the file
rather than with the user. This layer's rule is that where we cannot do what
was asked we fail loudly rather than approximately, and `encrypt_value` cannot
do what was asked — it cannot see which format it is writing for, and the two
disagree (YAML `sops -d` exit 0, JSON exit 4). That is k122, which is
where the encrypted slot gets the format it needs; when it lands, this row
becomes a `type:float` and the refusal goes away.

It is worth naming plainly that **this is a refusal where sops succeeds**, not
one where sops refuses. It is the one such row in this change, it is loud, it
names the key path, and its message already says a YAML document can carry the
value in an unencrypted slot.

## What was measured

- **The ticket's own rows.** `sops -e` → `File::SOPS->edit` (editor changes an
  unrelated key) → `sops -d`, for the three spellings `sops -e` writes: **3 of 3
  exit 0**, the unencrypted leaf byte-identical to what sops put there, the edit
  applied. All three croaked before. The same three through `sops edit`, side by
  side, for the reference answer: 3 of 3 exit 0.
- **The user editing the leaf itself**: `.inf` → `.nan`, `.inf` → `-.inf`,
  `.inf` → `5`. All three written and read back at exit 0; the first two
  croaked before.
- **The round trip with no editor in it**: `sops -e` → `decrypt_file` →
  `encrypt_file` → `sops -d`, three spellings, **3 of 3 exit 0** where all three
  croaked before.
- **The 24-row YAML corpus**, twelve tokens × two slots, each row a real
  `File::SOPS->encrypt_file` on a **plaintext** handed to `sops -d`:

  | slot | before | after |
  |---|---|---|
  | unencrypted | **0 written**, 12 croak | **12 written**, `sops -d` exit 0 |
  | encrypted | 12 written as `type:str` | **12 croak**, naming the key path |

  Our wire keeps the source spelling for all twelve; sops's own emitter
  normalises the nine it does not write down to `.inf` / `-.inf` / `.nan`, which
  is why `sops -d` prints the normalised token for a document whose wire says
  `+.INF`. For the three spellings `sops -e` itself writes, our wire and sops's
  are byte-identical.
- **JSON: 24 rows, 0 move.** `.inf` is not JSON and the parse refuses it before
  anything here is reached; a quoted `".inf"` is the string it always was.
- **The rows that must not move**, every one a document sops writes and reads:
  the twelve tokens single- and double-quoted (24), the twelve near misses
  (`.INf` `.iNF` `.Nan` `.NAn` `+.nan` `-.nan` `-.NAN` `.infinity` `.Infinity`
  `Inf` `inf` `NaN`), the leaves that merely contain the bytes (`config.info`,
  `.infrastructure`), ADR 0023's overflow class (`1e400`, `1e309`) and the
  ordinary numbers (`0`, `007`, `3.14`, `-0.0`, `1e3`). **None moves.**
- `prove -lr t/` was 1100/1100 at 0da0170 (49 files) and is **1116/1116** (50
  files) with the new file and the two replaced claims below.
  `SOPS_BIN=/tmp/sops prove -l t/04-interop.t` is **32/32, executed rather than
  skipped**, before and after.
- **Counter-check:** `t/49-plain-infinity-survives-the-plaintext-round-trip.t`
  run against the unpatched 0da0170 with `perl -I` and no `use lib` in the file
  — **9 of its 16 subtests and 115 assertions fail**, and every one of the seven
  that pass is a must-not-move section (the quoted tokens, the near misses, the
  contained bytes, ADR 0023's leaves, the finite numbers, JSON, and k134).

### The two claims this replaces

Both pinned the gate rather than the thing they were written to protect, and
both are edited in place rather than deleted, with the replacement named:

- **`t/39` section 2**, `the twelve tokens Go reads as a float are untouched`.
  Its comment says it pins ADR 0023's disjointness — that walk's predicate
  reads public `SVf_NOK` and these tokens arrive from `YAML::XS` POK-only — but
  it asserted the *final* parse result, which is a strictly stronger claim and
  is exactly the gate. The disjointness itself is untouched: ADR 0023's walk
  still runs first, over the same leaves, and still cannot fire on them. The
  subtest now asserts that ADR 0026's repair reaches the leaf and ADR 0023's
  does **not** undo it, which is what "they do not fight" actually looks like
  from outside.
- **`t/42` section 3**, `a plaintext document is not repaired`. This is the gate
  itself, and it is now `a plaintext document is repaired the same way a wire
  document is` — asserted against the wire document's own leaf rather than
  against a constant, so the claim is the equality rather than a second copy of
  the table.

### Cost

Unchanged for a document that does not hold one of these tokens, and the shape
is ADR 0026's own. Measured per `parse`, best of seven, before (gate on) and
after (gate off), on a **plaintext** document — the only input whose cost moves:

| document | before | after |
|---|---|---|
| 20 leaves, no token | 0.061 ms | **0.056 ms** |
| 20 leaves, a `config.info` key | 0.058 ms | 0.094 ms |
| 20 leaves, one bare `.inf` | 0.058 ms | 2.4 ms |
| 1000 string leaves, no token | 2.34 ms | **2.49 ms** |
| 1000 string leaves, one bare `.inf` | 2.30 ms | 104 ms |

The first gate — one scan of the raw bytes for `.inf` / `.nan` and their cases —
is what keeps the ordinary rows free, and it is why a plaintext that never
mentions a token pays nothing at all. A plaintext that really holds one pays a
second `YAML::PP` load and one parallel walk, once per `encrypt_file`,
`encrypt_in_place` or `edit` call, and it is paid only by documents that were
refused outright before.

The one new exposure worth naming: `YAML::PP` now loads caller-supplied
**plaintext** as well as wire content. It is reached only for a document
`YAML::XS` has already loaded successfully and that holds a candidate leaf, so
it is a second expansion of something already expanded, and ADR 0026's fail-safe
still discards the whole repair if `YAML::PP` refuses the document or the two
trees disagree about its shape. `t/41` and `t/43` (the recursive anchor and the
alias bomb) pass unchanged.

## Consequences

### Wire bytes that move

One document class, in one direction: a **plaintext** YAML document holding a
plain `%GO_CONSTANT` token in an unencrypted slot now encrypts to a file that
states that token and whose digest covers `+Inf` / `-Inf` / `NaN`. That is what
`sops -e` writes and digests for the same plaintext, and for the three spellings
sops itself writes the bytes are identical.

Nothing else moves. No document this library could write before is written
differently, and no encrypted slot's bytes change in any row.

### What changes for existing callers

| input | before | after |
|---|---|---|
| `edit` of a sops-written YAML document with a bare `.inf` / `-.inf` / `.nan` in an **unencrypted** slot, editing any key | croak, ADR 0013's guard, **the edit destroyed** | **written**, `sops -d` exit 0, the leaf byte-identical |
| `encrypt_file` / `encrypt_in_place` of a **plaintext** holding the same, any of the twelve spellings | croak | **written**, `sops -d` exit 0 |
| `decrypt_file` → `encrypt_file` of this library's own output for such a document | croak | **round-trips** |
| the same token in an **encrypted** slot of a plaintext | written as `type:str` holding the token | **croak**, naming the key path (k122) |
| a **quoted** `".inf"` / `'.inf'` anywhere | the string, both slots | **unchanged** |
| `.INf` `.iNF` `+.nan` `.infinity` `Inf` `NaN` and the rest of the near misses | a string | **unchanged** |
| `config.info`, `.infrastructure`, `1e400`, `007`, `-0.0` | as they were | **unchanged** |
| any **JSON** document, either slot | as it was | **unchanged** |
| `decrypt` / `extract` / `rotate` of a wire document | ADR 0026 and ADR 0031's behaviour | **unchanged** — the gate only ever excluded plaintext |
| `Format::YAML->parse` called directly on a plaintext | the token as a string | the float, carrying the token as its text |

### What this leaves broken, and why it is filed rather than fixed

- **`edit` still silently retypes a non-finite float in an ENCRYPTED slot.**
  Such a leaf decrypts to a real Perl infinity, which this emitter writes into
  the plaintext as a bare `Inf` / `-Inf` / `NaN` — tokens go-yaml reads as
  **strings**, and correctly so. The editor is shown `Inf`, the string `Inf`
  comes back, and the leaf is re-encrypted as a `type:str`. Measured: the file
  is written, nothing is said, `sops -d` exit 0, and `sops edit` on the same
  document keeps it a `type:float`. This ADR's repair cannot reach it — `Inf`
  is not a `%GO_CONSTANT` token, and must not become one, because a user who
  types `Inf` really does mean the string. The fix is at the **emit**, where
  the information is actually destroyed, and it needs `Encrypted.pm`:
  `_canonical_floats` short-circuits a non-finite leaf with `return $node`
  before any handler hook is reached, so the YAML handler's `carrier` never
  sees it, and putting the decision in the handler would be a second copy of
  `NO_AGREED_FORM`. k134, wire lane. The same defect makes `decrypt_file`
  diverge from `sops -d` for that document, with no editor involved.
- **A string leaf whose spelling libyaml leaves bare is still refused where
  sops quotes it.** Measured, plaintext `v_unencrypted: ".inf"` — a string to
  both implementations: `sops -e` writes `".inf"` quoted and `sops -d` reads it
  at exit 0, while `encrypt_file` croaks from ADR 0013's guard, along with
  `"1_000"`, `"2015-01-01"` and `"0o10"`. ADR 0013 rejected quoting on the
  grounds that it retypes the leaf, which is true of `mode: 0755` and false of
  a leaf that is already a string. Pre-existing, unmoved by this change, and
  filed as k135.
- **`edit` destroys the edit whenever the re-encryption refuses**, whatever the
  reason. This change removes one cause; the loss itself is untouched, and it is
  a real decision rather than a bug fix — the temporary file is deliberately
  removed on every way out, which the POD documents as a security property, and
  sops's own answer (reopen the editor until it parses) needs a terminal a
  library cannot assume.

## Rejected alternatives

**Thread a flag from `edit` into `parse`.** Measured and tabled above: it fixes
the ticket's rows and leaves `edit` and `encrypt_file` answering oppositely to
the identical bytes, in both directions, and leaves the `decrypt_file` →
`encrypt_file` round trip broken. Two rules where sops has none.

**Keep `edit`'s tree instead of round-tripping through text.** The editor edits
a *file*; the user may rewrite any part of it, including the leaf. A tree kept
alongside could only be consulted for leaves whose text came back unchanged,
which makes the resolution of a value depend on whether the user happened to
touch it — a rule that is impossible to state honestly in the POD and that
still croaks for `.inf` → `.nan`, a row this change makes work.

**Write a marker into the plaintext** — `!!float .inf`, or anything else that
survives our own reparse. It diverges from what `sops -d` and `decrypt_file`
write, which is a byte-identity ADR 0026 established on purpose; it shows the
user a document sops would not have written; and it does not survive the editor,
which is the one thing the document is handed over for.

**Refuse with a better message.** k123's option (c), and it is honest about
today rather than useful: the user still loses the edit, and the document is one
this library can now write. A better message for a refusal that no longer has to
happen.

**Repair the leaf in `edit` after the reparse, keyed on its text.** It is the
text-keyed repair ADR 0026 rejected with a counter-example that has not gone
away: `- .inf` and `- ".inf"` in one list are two different values with two
different digests, and only the document can tell them apart. The oracle already
in `parse` is the thing that knows; the fix is to stop preventing it from
running.

**Narrow the gate to "a document with no MAC that this library emitted".** There
is no such fact available at a parse. `parse` is handed bytes; provenance is not
in them, which is the whole reason a marker was considered. And the two callers
that would qualify — `edit`'s reparse and `encrypt_file` on a `decrypt_file`
output — are not distinguishable from a plaintext a user typed, nor should they
be: the bytes are the same and sops reads them the same.
