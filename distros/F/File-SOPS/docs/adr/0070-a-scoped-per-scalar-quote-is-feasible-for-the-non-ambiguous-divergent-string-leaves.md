# ADR 0070 — A scoped per-scalar quote is feasible for the divergent string leaves that parse unambiguously

- Status: **accepted** — 2026-09-01, by the maintainer, who cleared k99 to
  build. The Decision's scoped mechanism (sentinel substitution with fail-closed
  verification, the nine measured-safe rows only) is authorized for implementation;
  the sixteen ambiguous rows stay refused pending a full k127. The
  feasibility tables below were measured against sops 3.13.3 at `.sops-bin/sops`;
  the surgery mechanism was probed in a scratch copy before anything moved.
- Date: 2026-09-01
- Tags: yaml, emitter, wire-format, guards, interop
- Answers k99 ("Quoting a True/False string on the way out … needs a real
  emitter"), which ADR 0019 filed "for the maintainer to decide against a real
  emitter rather than in passing", and which ADR 0038/0039 named as the first of
  two gates on k135
- Depends on ADR 0008 (a leaf the emitter cannot write as the text the digest
  covers is refused — this proposes making the emitter able for a scoped set),
  ADR 0013/0017 (the foreign-resolution guard and the token it answers from),
  ADR 0019 (the `True`/`False` `type` divergence and the write-path surgery it
  rejected), ADR 0026/0034 (a plain non-finite scalar is resolved as go-yaml
  resolves it at parse — the only reason seven rows are unambiguous), ADR 0028
  (read-path text surgery, allowed under conditions this write-path case must
  meet another way), ADR 0038/0039 (the 22-row corpus and the decomposition this
  ADR corrects), ADR 0002 (the type comes from the SV — untouched here)
- **Corrects a premise in ADR 0039.** ADR 0039 wrote that k99 + k127
  would make all 22 rows writable "because the bare/quoted ambiguity … disappears
  at the parse". k127 has since landed, and the ambiguity did **not**
  disappear: the landed `_go_repair_int_leaves` repairs leading-zero integers
  only, none of which are in the 22. See "What was measured", §2.

## Context

Three separate decisions have named "quote the leaf on the way out" as the fix
they could not take, and filed it here:

- **ADR 0013** rejected it for `mode: 0755`, where quoting an *integer* leaf
  retypes it to a string sops never wrote — the maintainer's decision, and not
  what this ADR revisits.
- **ADR 0019** rejected it for a `True`/`False` *string*, where quoting retypes
  nothing (the leaf is already a string) and is measured to be exactly what sops
  writes — but it "moves wire bytes for a class of documents that are accepted
  today", and "YAML::XS has no per-scalar style control", so it filed k99.
- **ADR 0038/0039** found 22 (then 23) *string* leaves that sops writes
  double-quoted, reads back at exit 0, and this library refuses — and handed the
  emitter half to the wire lane as k99, the parse half to k127.

All three turn on one missing capability: forcing exactly one chosen scalar to be
double-quoted in the YAML::XS output, at an arbitrary key path and arbitrary
nesting, without moving any other leaf's bytes. This ADR measures whether that
capability can be built **safely** with the emitter (YAML::XS::Dump) and parser
this distribution actually has, and — because the answer is "yes, for a scoped
subset" — states the mechanism, the corpus check that would prove it, and the
effort, for the maintainer to decide against.

The hard constraint is unchanged and not in question: the emitter stays
YAML::XS::Dump and must remain byte-identical for every document accepted today.
Switching to YAML::PP for emission would move the wire bytes of every document
(indent, key order, quoting) and break self-verification and interop wholesale.
The per-scalar quote must live *within* the YAML::XS output.

## What sops does

Measured, sops 3.13.3, one age recipient, YAML, leaf in an unencrypted slot:

| plaintext source | what `sops -e` writes | `sops -d` |
|---|---|---|
| `x_unencrypted: True` | `x_unencrypted: true` (bool) | exit 0 |
| `x_unencrypted: "True"` | `x_unencrypted: "True"` (str) | exit 0 |
| `x_unencrypted: ".inf"` | `x_unencrypted: ".inf"` (str) | exit 0 |
| `x_unencrypted: ".nan"` | `x_unencrypted: ".nan"` (str) | exit 0 |
| `z_unencrypted: "-.inf"` | `z_unencrypted: "-.inf"` (str) | exit 0 |

So for a leaf that is a string, sops writes it double-quoted and reads it back;
it resolves nothing. That is the document this library must be able to produce.

**Quoting does not move the MAC digest.** Measured directly: sops's own document
with `x_unencrypted: "True"` (a valid MAC over the string bytes `True`) was
edited to un-quote that one leaf to a bare `True`, leaving the stored MAC
untouched, and handed back to `sops -d`:

| document handed to `sops -d` | sops reads the leaf as | `sops -d` |
|---|---|---|
| `x_unencrypted: "True"` (as sops wrote it) | `str "True"` | exit 0 |
| `x_unencrypted: True` (un-quoted, same MAC) | `bool true` | exit 0 |

Both verify against the *same* MAC, because the digest input is the byte string
`True` either way — go-yaml renders a boolean Title-cased, which is the string a
quoted `"True"` already is. Quoting therefore changes only which *type* sops
reads; it never changes the digest, and it never changes this library's digest,
which is computed over the plaintext tree before serialization. This is the fact
k99 rests on, and it is confirmed rather than assumed.

## What was measured

### 1. There is a safe per-scalar quote mechanism — sentinel substitution with fail-closed verification

Three routes to a *cheaper* mechanism were re-confirmed dead, as ADR 0039 found:
YAML::XS exposes no per-scalar style hook (its whole option surface is
`Boolean`, `LoadBlessed`, `LoadCode`, `UseCode`, `DumpCode`, `Indent`,
`ForbidDuplicateKeys`, `QuoteNumericStrings`); `$YAML::XS::QuoteNumericStrings`
is a boolean that quotes only what `looks_like_number` accepts plus lower-case
`true`/`false`/`null`/`~`; and a dualvar carrier makes quoting *worse*, writing
even `0755` bare. So the only route is text surgery on the finished document —
the generalization of `_quote_sops_timestamp`, which has done exactly this for
one metadata key since 0.003.

The generalization ADR 0019 feared — "find an arbitrary key path at arbitrary
nesting in a finished document, and a mis-hit writes a corrupt file" — is not
the only design available. The **sentinel** design ADR 0039 costed and called
"genuinely stronger than ADR 0028's count check" avoids path-location entirely:

1. Before `Dump`, replace each safely-quotable leaf's value with a unique random
   128-bit sentinel token (a plain alphanumeric string YAML::XS emits bare and
   on one line), recording sentinel → original value.
2. `Dump` the tree. Each sentinel appears once, as a bare token.
3. In the text, replace each sentinel with the original value rendered as a YAML
   double-quoted scalar (backslash/quote/control-char escaped).
4. **Verify, fail closed:** each sentinel must occur exactly once (a count of 0
   or >1 abandons the surgery), and the finished document is re-`Load`ed and the
   leaf at each recorded position compared byte-for-byte against the original. A
   mismatch or a count miss falls back to today's refusal — never a shipped file.

Probed against a tree with target leaves at the top level, in a deeply nested
mapping, and as sequence elements, alongside non-target neighbours and a value
containing `"` and `\`:

```
nested:
  deep:
    x: "False"
  list:
  - ".nan"
  - keepme            <- untouched
  - "-.inf"
normal: ordinary string   <- untouched
top_inf: ".inf"
top_true: "True"
withquote: "has \"quotes\" and \\ backslash"
```

**0 misses; all six forced leaves re-`Load` to their exact originals; every
non-target leaf byte-identical.** The mechanism reaches arbitrary nesting,
escapes correctly, and moves no other leaf's bytes. Because the digest is
computed over the original tree in `File::SOPS::_compute_mac` — before `emit`
runs — and the sentinel is only a transient value substitution that never
touches a key, the surgery cannot move a digest byte or a key's sort position.

### 2. The bare/quoted ambiguity is UNCHANGED by k127 — only seven rows parse unambiguously

This is the finding that scopes the whole ticket, and it corrects ADR 0039.
k127 is now **done**, but the landed `_go_repair_int_leaf` repairs a leaf
only when it is `SVf_IOK` **and** its PV matches `/\A[+-]?0\d+\z/` — a
leading-zero *integer*. None of the 22/23 divergent spellings are leading-zero
integers. So the ambiguity ADR 0039 measured is exactly as wide today as it was
then. Measured, each spelling parsed from a **bare** and a **quoted** source
through `Format::YAML->parse`, compared by `detect_type` + `value_to_bytes`:

| family | rows | bare parses as | quoted parses as | distinguishable? |
|---|---|---|---|---|
| `.inf .Inf .INF +.inf -.inf .nan .NaN` | **7** | `float` `+Inf`/`-Inf`/`NaN` | `str`, the token | **yes** |
| `1_000 0_7 685_230.15` | 3 | `str`, the token | `str`, the token | no |
| `2015-01-01 2015-1-2 2015-01-01t12:00:00Z 2015-01-01 12:00:00` | 4 | `str`, the token | `str`, the token | no |
| `0o10 0O10 0x1f 0b101` | 4 | `str`, the token | `str`, the token | no |
| `Null NULL TRUE FALSE` | 4 | `str`, the token | `str`, the token | no |
| `0xffffffffffffffff` | 1 | `str`, the token | `str`, the token | no |

The seven that parse unambiguously do so because of ADR 0026/0034, not k127:
a bare `.inf` is resolved to a float at parse, so a leaf that is *still the
string* `.inf` can only have come from a quoted scalar or a caller's own Perl
string. Quoting it is therefore safe — it states the type the leaf already has.

For the other sixteen, a bare and a quoted source arrive as the identical Perl
string, and the two sources are *different documents* to sops: a bare `1_000` is
`1000`, a bare `Null` is `null`, a bare `2015-01-01` is `2015-01-01T00:00:00Z`.
Quoting a leaf whose source was bare would write a **string** where sops writes a
resolved value — turning today's loud refusal into a silent value divergence,
the direction ADR 0032 and ADR 0038 both refused. The emitter cannot tell the
two sources apart, so it cannot safely quote these until the *parse* disambiguates
them — which is the full k127 (resolve every plain scalar the way Go does),
**not** the leading-zero-only slice that landed.

### 3. `True`/`False` are safely quotable although they are not parse-distinguishable

`True`/`False` are in the "no" column above — bare `True` and quoted `"True"`
both parse to `str "True"` — yet quoting them is safe where quoting the date
family is not. The difference is the axis of the divergence:

- `True`/`False` are a **`type` divergence** (ADR 0019): the digest **bytes
  agree** (`True` both sides), and only the type differs (str here, bool to Go).
  Quoting is MAC-neutral (measured, §"What sops does") and *removes* the
  divergence — the caller's string stays a string on both sides, and a sops
  write-back keeps it (`sops -e "True"` → `"True"`), where a bare `True` is
  rewritten to `true` and the caller's string silently becomes a boolean.
- `1_000`, `0x1f`, `Null`, the dates are a **`mac` divergence** (ADR 0013): the
  digest **bytes differ**. A bare-sourced one carries a value we cannot
  reconstruct, so quoting is a silent value change.

So the safe-to-quote set is decided by the guard's own verdict, not by parse
distinguishability: a `type` divergence is always safe (bytes agree, quoting is
neutral), and a `mac` divergence is safe only where the leaf parses
unambiguously (the seven non-finite).

### 4. sops accepts the bytes the mechanism would produce

Measured above and in ADR 0039: sops writes `".inf"`, `".nan"`, `"-.inf"` and
`"True"` in unencrypted slots itself, and `sops -d` reads all of them back at
exit 0. Combined with §"What sops does" (our digest of `str ".inf"` is `.inf`,
the token sops digests from the quoted form; our digest of `str "True"` is
`True`, the same either way), the documents the mechanism would emit are exactly
the ones sops already round-trips.

## Decision (proposed)

**A scoped per-scalar quote is feasible and safe, and this ADR proposes building
it — as sentinel substitution with fail-closed verification, applied only to the
leaves whose safety is measured, on the MAC-covered YAML write path.**

The scope is what §2 and §3 establish is safe **today**, and no wider:

- **The `type` divergence class** — a `str` leaf whose emitted token go-yaml
  resolves to a boolean (`True`, `False`). Quoting it turns today's `carp`
  (ADR 0019) into a written, self-consistent document. This is k99's
  headline.
- **The seven parse-unambiguous non-finite `str` leaves** —
  `.inf .Inf .INF +.inf -.inf .nan .NaN`. Quoting turns today's refusal
  (ADR 0013) into a written document. This is 7 of the 22 rows of ADR 0038/0039.

**Everything else stays exactly as it is.** The sixteen ambiguous rows
(`1_000 0_7 685_230.15`, the four dates, `0o10 0O10 0x1f 0b101`,
`Null NULL TRUE FALSE`, `0xffffffffffffffff`) stay **refused**, with the message
ADR 0039 already corrected, until the full k127 disambiguates their source
at parse. An integer/float `mac` divergence (`0755`, `010`) stays refused
(ADR 0013 — quoting would retype it, and the maintainer decided against that).
The plaintext emitters (`decrypt_file`, `edit`) install no guard and are not in
scope here; a related plaintext-path fidelity gap is filed separately (see
Consequences).

### The corpus check that would prove it

The proof is the ADR 0019 corpus, re-run before and after: **91 leaves × 2 slots
(`x_unencrypted`, `x`) × both handlers = 364 rows**, each encrypted and handed to
`sops -d`, plus each newly-writable row also `sops rotate`d and read back to
prove stability. The assertions:

1. **Exactly nine rows move**, all YAML unencrypted-slot: the two `True`/`False`
   rows and the seven non-finite rows. Each moves from `carp`+bare (True/False)
   or from refusal (non-finite) to a double-quoted leaf, `sops -d` exit 0, the
   string read back intact, and `sops rotate` re-writing the same quoted token.
2. **No other row moves.** All 355 remaining rows are byte-identical documents
   with identical `sops -d` exit codes — in particular every adversarial
   neighbour that must **stay bare**: `007`, `08`, `1e3` (int here, agree),
   `null`, `~` (quoted by libyaml already), `yes` `no` `on` `off` `y` `n`
   (str both sides, agree), `1:30`, `123abc`, `2024-invoice`, and
   `2015-01-01T12:00:00Z` (str here, `time` to Go, but same bytes and no other
   spelling — ADR 0019 does not warn about it and this must not quote it), and a
   real `JSON::PP::Boolean` (emitted bare `true`, must not be quoted).
3. **The sixteen ambiguous rows stay refused**, and the refusal message is
   unchanged.
4. **The sentinel verification is exercised for failure**: a forced test where
   the re-`Load` comparison fails must fall back to the refusal, never emit.

Representative measurement already taken (the load-bearing rows):

| row | today | under the mechanism | sops |
|---|---|---|---|
| `x_unencrypted: "True"` (str) | `carp`, bare `True`, sops reads bool | `"True"`, sops reads str | `sops -e "True"` → `"True"`, exit 0 |
| `x_unencrypted: ".inf"` (str) | refused | `".inf"`, sops reads str | `sops -e ".inf"` → `".inf"`, exit 0 |
| `x_unencrypted: yes` (str) | bare `yes`, agree | **bare `yes`** (must not move) | `sops -e yes` → `yes`, exit 0 |
| `x_unencrypted: 2015-01-01` (str) | refused | **still refused** | bare source → `2015-01-01T00:00:00Z` |
| `x_unencrypted: true` (bool) | bare `true`, agree | **bare `true`** (must not move) | bool, exit 0 |

### Effort estimate

- **Wire (`Format::YAML.pm`):** a pre-`emit` classification+substitution walk
  (which divergent leaves are in the safe set; substitute a sentinel, record
  original), a `_quote_sentinels` surgery+verify routine generalizing
  `_quote_sops_timestamp` (count check, re-`Load`, fail-closed fallback to the
  existing guard), and a YAML double-quote escaper. The safe-set predicate reuses
  `_foreign_resolution_token` (the `type` verdict gives True/False) plus one new
  predicate for the seven parse-unambiguous non-finite `str` leaves. Roughly
  **150–250 lines**, all in `Format::YAML`, no change to `Encrypted.pm` or the
  MAC paths, no change to `canonical_float_tree`'s contract (the sentinel'd tree
  passes the existing guard because a sentinel is an ordinary string).
- **Test:** the 364-row corpus harness above driving the real binary, plus the
  fail-closed unit test, plus byte-identity assertions for the 355 unmoved rows.
  A substantial new `t/` file, in the shape of `t/53`.
- **Sequencing:** wire-lane change (moves wire bytes for the nine-row class), so
  it wants its own implementation ADR recording the corpus results, and an
  interop run that **executes** rather than skips. This ADR is the decision that
  authorizes that work; it does not perform it.

## Consequences

- **No code changes in this pass.** `prove -lr t/` and
  `SOPS_BIN=.sops-bin/sops prove -lv t/04-interop.t` are unaffected — nothing
  under `lib/` moved. This ADR adds one file under `docs/`.
- **If built, nine documents that cannot be written today become writable**, each
  byte-identical to sops's own output and stable across a sops write-back. No
  document that is written today changes, and no document that is refused today
  other than the seven non-finite is written.
- **k99 is answerable for its headline (True/False) and for 7 of the 22
  ADR 0038 rows, but not for the other 16.** ADR 0039's "k99 + k127 →
  all 22" is corrected: the landed k127 does not disambiguate the sixteen,
  and a *full* k127 (resolve every plain scalar as go-yaml does, at parse,
  moving the value/ciphertext/digest of every affected document — ADR 0002's
  territory) remains the precondition for them.
- **A separate plaintext-path fidelity gap surfaced while measuring** and is
  filed rather than folded in: `decrypt_file` writes a quoted-non-finite `str`
  leaf back as a **bare** token (`sops -d` gives `".inf"`, this library's
  `decrypt_file` gives `.inf`), so a `decrypt_file` → re-encrypt round trip flips
  such a leaf from string to float. Same root cause (no per-scalar quote), the
  plaintext emitter (no guard, out of this ADR's scope). New karr ticket.

## Rejected alternatives

**Defer entirely, as ADR 0039 did.** ADR 0039 deferred because a fix "pre-empts
k99, which is the one thing ADR 0019 asked the next lane not to do" — and
this **is** k99, so that objection is spent. The remaining objection, a
corrupt file from a write-path mis-hit, is answered by the fail-closed sentinel
design: a count miss or a re-`Load` mismatch falls back to the refusal, so a
mis-hit cannot ship. Deferring now would leave the measured, safe nine rows
unwritten for no measured reason.

**Quote every `str` leaf the guard refuses.** Refused by §2: sixteen rows arrive
identically from a bare and a quoted source, and quoting a bare-sourced one is a
silent value divergence. The scope is exactly the rows where that cannot happen.

**Path-anchored surgery on the finished text (ADR 0019's feared form).** Locating
an arbitrary key path at arbitrary nesting in the emitted document is the
mechanism whose mis-hit ADR 0019 rejected, and it is avoidable: the sentinel is
substituted *before* `Dump`, so the surgery matches a unique random token, never
a path, and verifies the finished bytes by re-`Load`.

**Wait for the full k127 and do all 22 at once.** It is the complete answer
and a much larger, value-moving parse change (ADR 0002's territory, its own
corpus, its own ADR). Making the nine safe rows writable now does not block it
and does not overlap it: k127 changes what the *parse* produces, this
changes what the *emit* writes for a leaf that is already unambiguously a string.

**Switch the emitter to YAML::PP for per-node style control.** Out of bounds by
the hard constraint: it moves the wire bytes of every document and breaks
self-verification and interop wholesale.
